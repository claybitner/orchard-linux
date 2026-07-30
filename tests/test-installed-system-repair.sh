#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPAIR="$ROOT/scripts/repair-installed-system.sh"

bash -n "$REPAIR"

for expected_setting in \
  'set -Eeuo pipefail' \
  'vendor="$(cat /sys/class/dmi/id/sys_vendor' \
  'product="$(cat /sys/class/dmi/id/product_name' \
  'list_kernel_packages "$package_snapshot"' \
  'packages+=("${kernel_package}-headers")' \
  'pacman -Syu --needed "${packages[@]}"' \
  '"$ROOT/scripts/fetch-rounded-corners-source.sh" /usr/src/orchard' \
  "exclude='/etc/pacman.d/hooks/94-orchard-prebuild-live.hook'" \
  "exclude='/usr/share/applications/org.orchard.Install.desktop'" \
  'MACBOOK_ROUNDED_CORNERS_FORCE=1' \
  'macbook-wifi-driver.service' \
  '/usr/lib/macbook-cachyos/firstboot'; do
  grep -qF "$expected_setting" "$REPAIR" || {
    echo "Installed-system repair is missing: $expected_setting" >&2
    exit 1
  }
done

echo "Installed-system repair tests passed."
