#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

HOME_DIR="$TEST_ROOT/home"
BIN_DIR="$TEST_ROOT/bin"
APPLICATIONS_DIR="$TEST_ROOT/applications"
WALLPAPER="$TEST_ROOT/orchard-dusk.svg"
LOG="$TEST_ROOT/commands.log"

mkdir -p \
  "$HOME_DIR/.local/share/macbook-cachyos" \
  "$HOME_DIR/.config/autostart" \
  "$BIN_DIR" \
  "$APPLICATIONS_DIR"
touch "$HOME_DIR/.config/autostart/cachyos-hello.desktop"
touch \
  "$APPLICATIONS_DIR/org.kde.dolphin.desktop" \
  "$APPLICATIONS_DIR/firefox.desktop" \
  "$APPLICATIONS_DIR/com.shellyorg.shelly.desktop" \
  "$APPLICATIONS_DIR/org.orchard.Install.desktop" \
  "$APPLICATIONS_DIR/org.orchard.Downloads.desktop" \
  "$APPLICATIONS_DIR/org.orchard.Trash.desktop" \
  "$WALLPAPER"
cp \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/plasma-layout-once" \
  "$HOME_DIR/.local/share/macbook-cachyos/plasma-layout-once"
chmod 0755 "$HOME_DIR/.local/share/macbook-cachyos/plasma-layout-once"

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
cat > "$BIN_DIR/systemctl" <<EOF
#!/usr/bin/env bash
printf 'systemctl %s\n' "\$*" >> "$LOG"
exit 0
EOF
chmod 0755 "$BIN_DIR"/*

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
MACBOOK_SYSTEM_WALLPAPER="$WALLPAPER" \
MACBOOK_DECORATION_DIR="$ROOT/overlay/airootfs/usr/share/aurorae/themes/OrchardTrafficLights" \
MACBOOK_GTK_TRAFFIC_LIGHTS="$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/gtk-traffic-lights.css" \
MACBOOK_LOOK_AND_FEEL_DIR="$ROOT/overlay/airootfs/usr/share/plasma/look-and-feel/org.orchard.desktop" \
MACBOOK_TOUCHEGG_CONFIG="$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/touchegg.conf" \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/setup-plasma" "$HOME_DIR"

grep -qxF \
  "Exec=/usr/lib/macbook-cachyos/plasma-layout-once" \
  "$HOME_DIR/.config/autostart/macbook-plasma-layout.desktop"
grep -qF -- '--group General --key ColorScheme OrchardDark' "$LOG"
grep -qF \
  -- '--group KDE --key LookAndFeelPackage org.orchard.dark.desktop' \
  "$LOG"
grep -qF -- '--group org.kde.kdecoration2 --key ButtonsOnLeft XIA' "$LOG"
grep -qF -- '--key library org.kde.kwin.aurorae.v2' "$LOG"
grep -qF -- '--group kwin --key Overview Ctrl+Up' "$LOG"
grep -qF -- '--group kwin --key Window Minimize Meta+M' "$LOG"
grep -qF -- '--group org.kde.spectacle.desktop --key FullScreenScreenShot Meta+Shift+3' "$LOG"
grep -qF -- '--file krunnerrc --group General --key FreeFloating true' "$LOG"
grep -qF -- '--file kglobalshortcutsrc --group org.kde.krunner.desktop --key _launch' "$LOG"
grep -qF -- '--file baloofilerc --group General --key only basic indexing true' "$LOG"
grep -qF -- '--key theme __aurorae__svg__OrchardTrafficLights' "$LOG"
grep -qF \
  -- '--group Plugins --key kwin4_effect_shapecornersEnabled --type bool true' \
  "$LOG"
grep -qF -- '--group Round-Corners --key Size 12' "$LOG"
grep -qF -- '--file kscreenlockerrc --group Greeter --group Wallpaper' "$LOG"
grep -qF -- '--notify --file kscreenlockerrc --group Daemon --key Autolock --type bool false' "$LOG"
grep -qF \
  -- '--file ksplashrc --group KSplash --key Theme org.orchard.dark.desktop' \
  "$LOG"
cmp \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/touchegg.conf" \
  "$HOME_DIR/.config/touchegg/touchegg.conf"
cmp \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/gtk-traffic-lights.css" \
  "$HOME_DIR/.config/gtk-3.0/gtk.css"
grep -qxF 'GTK_MODULES=appmenu-gtk-module' \
  "$HOME_DIR/.config/environment.d/90-orchard-desktop.conf"
[[ ! -e "$HOME_DIR/.config/autostart/cachyos-hello.desktop" ]]
[[ -e "$HOME_DIR/.config/macbook-cachyos-defaults-v1" ]]

HOME="$HOME_DIR" \
PATH="$BIN_DIR:$PATH" \
MACBOOK_APPLICATIONS_DIR="$APPLICATIONS_DIR" \
MACBOOK_SYSTEM_WALLPAPER="$WALLPAPER" \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/plasma-layout-once"

grep -qF \
  'applications:org.kde.dolphin.desktop,applications:firefox.desktop' \
  "$LOG"
grep -qF 'applications:org.orchard.Install.desktop' "$LOG"
grep -qF 'applications:com.shellyorg.shelly.desktop' "$LOG"
grep -qF "$WALLPAPER" "$LOG"
grep -qF \
  'systemctl --user restart plasma-plasmashell.service' \
  "$LOG"
[[ -f "$HOME_DIR/.config/macbook-cachyos-plasma-layout-v5" ]]
[[ ! -e "$HOME_DIR/.config/autostart/macbook-plasma-layout.desktop" ]]

# Reapplying user defaults after the layout exists must not leave a stale
# autostart item behind.
HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/setup-plasma" "$HOME_DIR"
HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" MACBOOK_RESTART_PLASMASHELL=0 \
  "$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/plasma-layout-once"
[[ ! -e "$HOME_DIR/.config/autostart/macbook-plasma-layout.desktop" ]]

echo "Plasma setup tests passed."
