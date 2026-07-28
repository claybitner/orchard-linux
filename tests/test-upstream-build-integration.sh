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
"$ROOT/scripts/validate.sh" "$TEST_ROOT" desktop

echo "Upstream build integration tests passed."
