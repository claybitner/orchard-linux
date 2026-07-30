#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

LIB_DIR="$TEST_ROOT/usr/lib/macbook-cachyos"
BIN_DIR="$TEST_ROOT/bin"
LOG="$TEST_ROOT/commands.log"
mkdir -p \
  "$LIB_DIR" \
  "$BIN_DIR" \
  "$TEST_ROOT/etc/skel" \
  "$TEST_ROOT/usr/share/color-schemes"
cat > "$TEST_ROOT/usr/share/color-schemes/BreezeLight.colors" <<'EOF'
[General]
Name=Breeze Light
ColorScheme=BreezeLight
DecorationFocus=61,174,233
SelectionBackground=61,174,233
EOF
cat > "$TEST_ROOT/usr/share/color-schemes/BreezeDark.colors" <<'EOF'
[General]
Name=Breeze Dark
ColorScheme=BreezeDark
DecorationFocus=61,174,233
SelectionBackground=61,174,233
EOF

cat > "$LIB_DIR/build-rounded-corners" <<EOF
#!/usr/bin/env bash
[[ "\${MACBOOK_ROUNDED_CORNERS_FORCE:-0}" == 1 ]]
mkdir -p \
  "$TEST_ROOT/usr/lib/qt6/plugins/kwin/effects/plugins" \
  "$TEST_ROOT/usr/lib/qt6/plugins/kwin-x11/effects/plugins" \
  "$TEST_ROOT/var/lib/macbook-cachyos"
touch \
  "$TEST_ROOT/usr/lib/qt6/plugins/kwin/effects/plugins/kwin4_effect_shapecorners.so" \
  "$TEST_ROOT/usr/lib/qt6/plugins/kwin-x11/effects/plugins/kwin4_effect_shapecorners.so" \
  "$TEST_ROOT/var/lib/macbook-cachyos/rounded-corners-build"
printf '%s\n' rounded-corners >> "$LOG"
EOF
cat > "$LIB_DIR/setup-plasma" <<EOF
#!/usr/bin/env bash
home="\${1:?missing home}"
mkdir -p "\$home/.config/autostart"
touch \
  "\$home/.config/kdeglobals" \
  "\$home/.config/kwinrc" \
  "\$home/.config/autostart/macbook-plasma-layout.desktop" \
  "\$home/.config/macbook-cachyos-defaults-v1"
printf 'setup-plasma %s\n' "\$home" >> "$LOG"
EOF
cat > "$LIB_DIR/plasma-layout-once" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 0755 \
  "$LIB_DIR/build-rounded-corners" \
  "$LIB_DIR/setup-plasma" \
  "$LIB_DIR/plasma-layout-once"
cp \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/prebuild-live-environment" \
  "$LIB_DIR/prebuild-live-environment"
chmod 0755 "$LIB_DIR/prebuild-live-environment"

MACBOOK_PREBUILD_ROOT="$TEST_ROOT" "$LIB_DIR/prebuild-live-environment"

grep -qxF rounded-corners "$LOG"
grep -qxF "setup-plasma $TEST_ROOT/etc/skel" "$LOG"
[[ -x "$TEST_ROOT/etc/skel/.local/share/macbook-cachyos/setup-plasma" ]]
[[ -x "$TEST_ROOT/etc/skel/.local/share/macbook-cachyos/plasma-layout-once" ]]
[[ -e "$TEST_ROOT/etc/skel/.config/macbook-cachyos-defaults-v1" ]]
[[ ! -e "$LIB_DIR/prebuild-live-environment" ]]
grep -qxF 'Name=Orchard Light' \
  "$TEST_ROOT/usr/share/color-schemes/OrchardLight.colors"
grep -qxF 'Name=Orchard Dark' \
  "$TEST_ROOT/usr/share/color-schemes/OrchardDark.colors"
grep -qxF 'SelectionBackground=52,120,246' \
  "$TEST_ROOT/usr/share/color-schemes/OrchardDark.colors"

cat > "$BIN_DIR/kwriteconfig6" <<EOF
#!/usr/bin/env bash
printf 'kwriteconfig6 %s\n' "\$*" >> "$LOG"
EOF
cat > "$BIN_DIR/plasma-apply-colorscheme" <<EOF
#!/usr/bin/env bash
printf 'plasma-apply-colorscheme %s\n' "\$*" >> "$LOG"
EOF
cat > "$BIN_DIR/qdbus6" <<EOF
#!/usr/bin/env bash
printf 'qdbus6 %s\n' "\$*" >> "$LOG"
EOF
chmod 0755 "$BIN_DIR"/*

PATH="$BIN_DIR:$PATH" DISPLAY=:1 \
  "$ROOT/overlay/airootfs/usr/local/bin/orchard-theme" dark
grep -qF \
  'kwriteconfig6 --file kdeglobals --group General --key ColorScheme OrchardDark' \
  "$LOG"
grep -qxF 'plasma-apply-colorscheme OrchardDark' "$LOG"

mkdir -p "$TEST_ROOT/dmi" "$TEST_ROOT/state"
printf '%s\n' 'Apple Inc.' > "$TEST_ROOT/dmi/sys_vendor"
printf '%s\n' 'MacBookPro11,3' > "$TEST_ROOT/dmi/product_name"

cat > "$BIN_DIR/timeout" <<'EOF'
#!/usr/bin/env bash
shift
exec "$@"
EOF
cat > "$BIN_DIR/flatpak" <<EOF
#!/usr/bin/env bash
printf 'flatpak %s\n' "\$*" >> "$LOG"
EOF
cat > "$BIN_DIR/macbook-diagnostic-bundle" <<EOF
#!/usr/bin/env bash
printf 'diagnostics %s\n' "\$1" >> "$LOG"
touch "\$1"
EOF
chmod 0755 "$BIN_DIR"/*

PATH="$BIN_DIR:$PATH" \
MACBOOK_DMI_ROOT="$TEST_ROOT/dmi" \
MACBOOK_STATE_DIR="$TEST_ROOT/state" \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/background-setup"
PATH="$BIN_DIR:$PATH" \
MACBOOK_DMI_ROOT="$TEST_ROOT/dmi" \
MACBOOK_STATE_DIR="$TEST_ROOT/state" \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/background-setup"

[[ "$(grep -c '^flatpak ' "$LOG")" -eq 1 ]]
[[ "$(grep -c '^diagnostics ' "$LOG")" -eq 1 ]]
[[ -e "$TEST_ROOT/state/background-complete-v1" ]]
[[ -e "$TEST_ROOT/state/diagnostics.tar.gz" ]]

echo "Prebuilt live-environment tests passed."
