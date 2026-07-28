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

"$ROOT/scripts/apply-overlay.sh" "$TEST_ROOT" macbook-cachyos desktop
cp "$TEST_ROOT/util-iso.sh" "$TEST_ROOT/util-iso-first-pass"
"$ROOT/scripts/apply-overlay.sh" "$TEST_ROOT" macbook-cachyos desktop

cmp "$TEST_ROOT/util-iso-first-pass" "$TEST_ROOT/util-iso.sh"
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
  /usr/lib/macbook-cachyos/firstboot \
  /usr/lib/macbook-cachyos/patch-calamares \
  /usr/lib/macbook-cachyos/setup-plasma \
  /usr/lib/macbook-cachyos/plasma-layout-once; do
  grep -qxF \
    "  [\"$executable_path\"]=\"0:0:755\" # orchard-linux: executable overlay" \
    "$TEST_ROOT/archiso/profiledef.sh"
done
[[ "$(grep -cF '# orchard-linux: executable overlay' \
  "$TEST_ROOT/archiso/profiledef.sh")" -eq 7 ]]
"$ROOT/scripts/validate.sh" "$TEST_ROOT" desktop

echo "Upstream build integration tests passed."
