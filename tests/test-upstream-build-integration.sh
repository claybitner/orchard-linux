#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_ROOT/archiso/airootfs"
printf '%s\n' linux-cachyos > "$TEST_ROOT/archiso/packages_desktop.x86_64"
cat > "$TEST_ROOT/archiso/profiledef.sh" <<'EOF'
#!/usr/bin/env bash
iso_name="cachyos"
file_permissions=(
  ["/usr/local/bin/choose-mirror"]="0:0:755"
)
EOF
cat > "$TEST_ROOT/util-iso.sh" <<'EOF'
gen_iso_fn(){
    local vars=() name
    vars+=("cachyos")
}

run_build() {
    mv "$outFolder/$_profile/cachyos-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)-x86_64.iso" "$outFolder/$_profile/${iso_file}"
}
EOF
cat > "$TEST_ROOT/buildiso.sh" <<'EOF'
#!/usr/bin/env bash
set -e

trap_exit() {
  echo "unexpected EXIT trap" >&2
  return 1
}

gettext() {
  printf '%s\n' "$1"
}

trap 'trap_exit USR1 "$(gettext "An unknown error has occurred. Exiting...")"' ERR
trap 'trap_exit EXIT "$(gettext "An unknown error has occurred. Exiting...")"' EXIT

true
EOF
chmod 0755 "$TEST_ROOT/buildiso.sh"

"$ROOT/scripts/apply-overlay.sh" "$TEST_ROOT" macbook-cachyos desktop
cp "$TEST_ROOT/util-iso.sh" "$TEST_ROOT/util-iso-first-pass"
cp "$TEST_ROOT/buildiso.sh" "$TEST_ROOT/buildiso-first-pass"
"$ROOT/scripts/apply-overlay.sh" "$TEST_ROOT" macbook-cachyos desktop

cmp "$TEST_ROOT/util-iso-first-pass" "$TEST_ROOT/util-iso.sh"
cmp "$TEST_ROOT/buildiso-first-pass" "$TEST_ROOT/buildiso.sh"
grep -qxF 'iso_name="macbook-cachyos"' "$TEST_ROOT/archiso/profiledef.sh"
grep -qxF \
  '    vars+=("macbook-cachyos") # orchard-linux: ISO filename prefix' \
  "$TEST_ROOT/util-iso.sh"
grep -qF \
  '    mv "$outFolder/$_profile/macbook-cachyos-$(date ' \
  "$TEST_ROOT/util-iso.sh"
for executable_path in \
  /usr/local/bin/macbook-hardware-report \
  /usr/local/bin/macbook-diagnostic-bundle \
  /usr/local/bin/macbook-optional-theme \
  /usr/local/bin/orchard-theme \
  /usr/local/bin/orchard-trackpad \
  /usr/lib/macbook-cachyos/background-setup \
  /usr/lib/macbook-cachyos/build-rounded-corners \
  /usr/lib/macbook-cachyos/firstboot \
  /usr/lib/macbook-cachyos/live-welcome \
  /usr/lib/macbook-cachyos/patch-calamares \
  /usr/lib/macbook-cachyos/plasma-layout-once \
  /usr/lib/macbook-cachyos/setup-plasma \
  /usr/lib/macbook-cachyos/wifi-driver-setup; do
  grep -qxF \
    "  [\"$executable_path\"]=\"0:0:755\" # orchard-linux: executable overlay" \
    "$TEST_ROOT/archiso/profiledef.sh"
done
[[ "$(grep -cF '# orchard-linux: executable overlay' \
  "$TEST_ROOT/archiso/profiledef.sh")" -eq 13 ]]
[[ "$(grep -cF '# orchard-linux: removed unconditional EXIT error trap' \
  "$TEST_ROOT/buildiso.sh")" -eq 1 ]]
grep -qxF \
  'trap '\''trap_exit USR1 "$(gettext "An unknown error has occurred. Exiting...")"'\'' ERR' \
  "$TEST_ROOT/buildiso.sh"
"$TEST_ROOT/buildiso.sh"
grep -qxF '# remove from airootfs!' \
  "$TEST_ROOT/archiso/airootfs/etc/pacman.d/hooks/94-orchard-prebuild-live.hook"
grep -qxF 'Exec = /usr/bin/bash /usr/lib/macbook-cachyos/prebuild-live-environment' \
  "$TEST_ROOT/archiso/airootfs/etc/pacman.d/hooks/94-orchard-prebuild-live.hook"
[[ -L \
  "$TEST_ROOT/archiso/airootfs/etc/systemd/system/graphical.target.wants/macbook-background-setup.service" ]]
[[ -L \
  "$TEST_ROOT/archiso/airootfs/etc/systemd/system/multi-user.target.wants/macbook-wifi-driver.service" ]]
for data_path in \
  /usr/lib/macbook-cachyos/90-no-suspend.conf \
  /usr/lib/macbook-cachyos/70-bcm5974-libinput.conf \
  /usr/lib/macbook-cachyos/gtk-traffic-lights.css \
  /usr/lib/macbook-cachyos/hid-apple.conf \
  /usr/lib/macbook-cachyos/keyd-macos.conf \
  /usr/lib/macbook-cachyos/touchegg.conf; do
  [[ ! -x "$TEST_ROOT/archiso/airootfs$data_path" ]]
done
"$ROOT/scripts/validate.sh" "$TEST_ROOT" desktop

echo "Upstream build integration tests passed."
