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
grep -qxF '  - broadcom-wl-dkms' "$MODULES/pacstrap.conf"
grep -qxF '  - "/usr/lib/macbook-cachyos/firstboot"' "$MODULES/pacstrap.conf"
grep -qxF '   - name: "macbook-firstboot.service"' "$MODULES/services-systemd.conf"

echo "Calamares patch tests passed."
