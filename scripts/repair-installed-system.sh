#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="$ROOT/overlay/airootfs"

if (( EUID != 0 )); then
  echo "Run this repair through sudo:" >&2
  echo "  sudo ./scripts/repair-installed-system.sh" >&2
  exit 2
fi

for required_path in \
  "$OVERLAY/usr/lib/macbook-cachyos/firstboot" \
  "$OVERLAY/usr/lib/macbook-cachyos/prebuild-live-environment" \
  "$OVERLAY/usr/lib/macbook-cachyos/setup-plasma" \
  "$OVERLAY/usr/lib/macbook-cachyos/wifi-driver-setup"; do
  if [[ ! -f "$required_path" ]]; then
    echo "The Orchard repository is incomplete; missing $required_path" >&2
    exit 1
  fi
done

vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
if [[ "$vendor" != "Apple Inc." || "$product" != MacBook* ]]; then
  echo "This repair is limited to Apple MacBook hardware." >&2
  echo "Detected vendor='$vendor', product='$product'." >&2
  exit 1
fi

for command in pacman rsync systemctl; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

# shellcheck source=lib/packages.sh
source "$ROOT/scripts/lib/packages.sh"

package_snapshot="$(mktemp)"
cleanup() {
  rm -f -- "$package_snapshot"
}
trap cleanup EXIT
pacman -Qq > "$package_snapshot"

kernel_packages=()
while IFS= read -r kernel_package; do
  [[ -n "$kernel_package" ]] && kernel_packages+=("$kernel_package")
done < <(list_kernel_packages "$package_snapshot")

if [[ "${#kernel_packages[@]}" -eq 0 ]]; then
  echo "No supported installed kernel package was detected; refusing to guess its headers." >&2
  exit 1
fi

packages=(
  appmenu-gtk-module
  aurorae
  base-devel
  broadcom-wl-dkms
  capitaine-cursors
  cmake
  dkms
  extra-cmake-modules
  ffmpegthumbs
  flatpak
  fwupd
  inter-font
  intel-ucode
  iw
  iwd
  kdegraphics-thumbnailers
  keyd
  kdialog
  kimageformats
  kio-extras
  linux-firmware
  networkmanager
  ninja
  papirus-icon-theme
  pciutils
  plasma-browser-integration
  plasma-x11-session
  power-profiles-daemon
  qt6-imageformats
  rfkill
  rsync
  sddm
  shelly
  thermald
  touchegg
  usbutils
  vulkan-headers
  wireless-regdb
  xorg-xinput
)
for kernel_package in "${kernel_packages[@]}"; do
  packages+=("${kernel_package}-headers")
done

echo "Updating CachyOS and installing the Orchard system dependencies."
pacman -Syu --needed "${packages[@]}"

# The source archive is checksummed before it is placed under /usr/src.
"$ROOT/scripts/fetch-rounded-corners-source.sh" /usr/src/orchard

echo "Installing Orchard system files."
rsync -a \
  --exclude='/etc/pacman.d/hooks/94-orchard-prebuild-live.hook' \
  --exclude='/etc/pacman.d/hooks/99-macbook-calamares.hook' \
  --exclude='/etc/xdg/autostart/org.orchard.LiveWelcome.desktop' \
  --exclude='/usr/lib/macbook-cachyos/live-welcome' \
  --exclude='/usr/lib/macbook-cachyos/patch-calamares' \
  --exclude='/usr/share/applications/org.orchard.Install.desktop' \
  "$OVERLAY/" /

for executable_path in \
  /usr/local/bin/macbook-hardware-report \
  /usr/local/bin/macbook-diagnostic-bundle \
  /usr/local/bin/macbook-optional-theme \
  /usr/local/bin/orchard-theme \
  /usr/local/bin/orchard-trackpad \
  /usr/lib/macbook-cachyos/background-setup \
  /usr/lib/macbook-cachyos/build-rounded-corners \
  /usr/lib/macbook-cachyos/firstboot \
  /usr/lib/macbook-cachyos/plasma-layout-once \
  /usr/lib/macbook-cachyos/prebuild-live-environment \
  /usr/lib/macbook-cachyos/setup-plasma \
  /usr/lib/macbook-cachyos/wifi-driver-setup; do
  chmod 0755 "$executable_path"
done

rm -f -- \
  /etc/xdg/autostart/org.orchard.LiveWelcome.desktop \
  /usr/lib/macbook-cachyos/live-welcome \
  /usr/lib/macbook-cachyos/patch-calamares \
  /usr/share/applications/org.orchard.Install.desktop

# Generate the color schemes and /etc/skel profile against the installed
# Plasma/KWin ABI. The helper removes itself after completing successfully.
MACBOOK_ROUNDED_CORNERS_FORCE=1 \
  /usr/lib/macbook-cachyos/prebuild-live-environment

systemctl daemon-reload
systemctl enable \
  macbook-wifi-driver.service \
  macbook-firstboot.service \
  macbook-background-setup.service

# A previous partial attempt must not prevent the repaired integration from
# applying. Both helpers remain idempotent after these versioned markers return.
rm -f -- \
  /var/lib/macbook-cachyos/complete-v6 \
  /var/lib/macbook-cachyos/background-complete-v1
/usr/lib/macbook-cachyos/firstboot

echo
echo "Orchard repair completed for $product."
echo "Reboot now to load the persistent Wi-Fi service and the Orchard desktop."
