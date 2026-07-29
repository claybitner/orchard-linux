#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

MODULES="$TEST_ROOT/etc/calamares/modules"
mkdir -p "$MODULES"

cat > "$MODULES/pacstrap.conf" <<'EOF'
---
basePackages:
  - base
  - linux-cachyos
  - linux-cachyos-headers
  - linux-cachyos-lts
  - linux-cachyos-lts-headers

postInstallFiles:
  - "/etc/mkinitcpio.conf"
  - "/etc/calamares/scripts/btrfs-installation-snapshot"
EOF

cat > "$MODULES/services-systemd.conf" <<'EOF'
---
units:
   - name: "arch-update.timer"
     action: "enable"
     mandatory: false
     user: true

   - name: "arch-update-tray.service"
     action: "enable"
     mandatory: false
     user: true
EOF

MACBOOK_CALAMARES_ROOT="$TEST_ROOT" \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/patch-calamares"
cp "$MODULES/pacstrap.conf" "$TEST_ROOT/pacstrap-first-pass"
cp "$MODULES/services-systemd.conf" "$TEST_ROOT/services-first-pass"

MACBOOK_CALAMARES_ROOT="$TEST_ROOT" \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/patch-calamares"

cmp "$TEST_ROOT/pacstrap-first-pass" "$MODULES/pacstrap.conf"
cmp "$TEST_ROOT/services-first-pass" "$MODULES/services-systemd.conf"
grep -qxF '  - aurorae' "$MODULES/pacstrap.conf"
grep -qxF '  - appmenu-gtk-module' "$MODULES/pacstrap.conf"
grep -qxF '  - base-devel' "$MODULES/pacstrap.conf"
grep -qxF '  - broadcom-wl-dkms' "$MODULES/pacstrap.conf"
grep -qxF '  - capitaine-cursors' "$MODULES/pacstrap.conf"
grep -qxF '  - cmake' "$MODULES/pacstrap.conf"
grep -qxF '  - extra-cmake-modules' "$MODULES/pacstrap.conf"
grep -qxF '  - flatpak' "$MODULES/pacstrap.conf"
grep -qxF '  - inter-font' "$MODULES/pacstrap.conf"
grep -qxF '  - keyd' "$MODULES/pacstrap.conf"
grep -qxF '  - papirus-icon-theme' "$MODULES/pacstrap.conf"
grep -qxF '  - plasma-x11-session' "$MODULES/pacstrap.conf"
grep -qxF '  - sddm' "$MODULES/pacstrap.conf"
grep -qxF '  - shelly' "$MODULES/pacstrap.conf"
grep -qxF '  - touchegg' "$MODULES/pacstrap.conf"
grep -qxF '  - ninja' "$MODULES/pacstrap.conf"
grep -qxF '  - vulkan-headers' "$MODULES/pacstrap.conf"
grep -qxF '  - xorg-xinput' "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/etc/pacman.d/hooks/95-orchard-rounded-corners.hook"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/lib/macbook-cachyos/90-no-suspend.conf"' \
  "$MODULES/pacstrap.conf"
grep -qxF '  - "/usr/lib/macbook-cachyos/firstboot"' "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/lib/macbook-cachyos/70-bcm5974-libinput.conf"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/lib/macbook-cachyos/build-rounded-corners"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/lib/macbook-cachyos/gtk-traffic-lights.css"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/lib/macbook-cachyos/keyd-macos.conf"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/lib/macbook-cachyos/sddm-theme.conf.user"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/lib/macbook-cachyos/touchegg.conf"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/etc/xdg/autostart/org.orchard.TrackpadApply.desktop"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/etc/environment.d/90-orchard-input.conf"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/local/bin/orchard-trackpad"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/share/applications/org.orchard.Trackpad.desktop"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/share/applications/org.orchard.Trash.desktop"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/share/applications/org.orchard.Downloads.desktop"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/share/icons/hicolor/scalable/apps/orchard-menu.svg"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/share/aurorae/themes/OrchardTrafficLights/metadata.desktop"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/share/plasma/look-and-feel/org.orchard.desktop/metadata.json"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/share/wallpapers/macbook-cachyos/orchard-dusk.svg"' \
  "$MODULES/pacstrap.conf"
grep -qxF \
  '  - "/usr/src/orchard/KDE-Rounded-Corners-46b943637f9c1313f2a489c1d4b5e7fa08e01fc1.tar.gz"' \
  "$MODULES/pacstrap.conf"
grep -qxF '   - name: "macbook-firstboot.service"' "$MODULES/services-systemd.conf"

echo "Calamares patch tests passed."
