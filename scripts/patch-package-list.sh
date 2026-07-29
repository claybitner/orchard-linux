#!/usr/bin/env bash
set -Eeuo pipefail

ARCHISO="${1:?usage: patch-package-list.sh ARCHISO_DIR}"
PROFILE="${2:-desktop}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

PKGLIST="$(find_profile_package_list "$ARCHISO" "$PROFILE")"
echo "Using package list: $PKGLIST"

PACKAGES=(
  appmenu-gtk-module
  aurorae
  base-devel
  broadcom-wl-dkms
  capitaine-cursors
  cmake
  dkms
  extra-cmake-modules
  flatpak
  linux-firmware
  wireless-regdb
  networkmanager
  iwd
  iw
  rfkill
  pciutils
  usbutils
  dmidecode
  intel-ucode
  thermald
  power-profiles-daemon
  fwupd
  ffmpegthumbs
  inter-font
  kdegraphics-thumbnailers
  keyd
  kimageformats
  kio-extras
  papirus-icon-theme
  plasma-browser-integration
  plasma-x11-session
  qt6-imageformats
  sddm
  shelly
  touchegg
  ninja
  vulkan-headers
  xorg-xinput
)

append_package() {
  local pkg="$1"
  grep -qxF "$pkg" "$PKGLIST" || printf '%s\n' "$pkg" >> "$PKGLIST"
}

for pkg in "${PACKAGES[@]}"; do
  append_package "$pkg"
done

# DKMS needs headers matching every included kernel. Handle common Arch/CachyOS
# names and avoid accidentally treating an existing -headers package as a kernel.
KERNELS=()
while IFS= read -r kernel; do
  [[ -n "$kernel" ]] && KERNELS+=("$kernel")
done < <(list_kernel_packages "$PKGLIST")

if [[ ${#KERNELS[@]} -eq 0 ]]; then
  echo "WARNING: no kernel package was detected. Adding linux-headers as fallback." >&2
  append_package linux-headers
else
  for kernel in "${KERNELS[@]}"; do
    append_package "${kernel}-headers"
  done
fi

sort -u "$PKGLIST" -o "$PKGLIST"
