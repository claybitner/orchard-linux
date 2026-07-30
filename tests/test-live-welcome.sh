#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/live-welcome"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

ARCHISO_ROOT="$TEST_ROOT/run/archiso"
APPLICATION="$TEST_ROOT/org.orchard.Install.desktop"
INSTALLER="$TEST_ROOT/installer"
DESKTOP="$TEST_ROOT/home/Desktop"
MARKER="$TEST_ROOT/home/.cache/welcome-shown"
BIN_DIR="$TEST_ROOT/bin"
LOG="$TEST_ROOT/commands"

mkdir -p "$ARCHISO_ROOT" "$BIN_DIR"
cat > "$APPLICATION" <<'EOF'
[Desktop Entry]
Type=Application
Name=Install Orchard Linux
EOF
cat > "$INSTALLER" <<EOF
#!/usr/bin/env bash
printf '%s\n' installer >> "$LOG"
EOF
cat > "$BIN_DIR/kdialog" <<EOF
#!/usr/bin/env bash
printf 'kdialog %s\n' "\$*" >> "$LOG"
exit "\${KDIALOG_RESULT:-1}"
EOF
cat > "$BIN_DIR/gio" <<EOF
#!/usr/bin/env bash
printf 'gio %s\n' "\$*" >> "$LOG"
EOF
chmod 0755 "$INSTALLER" "$BIN_DIR/kdialog" "$BIN_DIR/gio"

HOME="$TEST_ROOT/home" \
PATH="$BIN_DIR:$PATH" \
KDIALOG_RESULT=1 \
ORCHARD_ARCHISO_ROOT="$ARCHISO_ROOT" \
ORCHARD_INSTALL_APPLICATION="$APPLICATION" \
ORCHARD_INSTALLER="$INSTALLER" \
ORCHARD_WELCOME_MARKER="$MARKER" \
ORCHARD_DESKTOP_DIR="$DESKTOP" \
ORCHARD_PROMPT_DELAY=0 \
  "$SCRIPT"

[[ -x "$DESKTOP/Install Orchard Linux.desktop" ]]
[[ -e "$MARKER" ]]
grep -qF -- '--yes-label Install now' "$LOG"
grep -qF -- '--no-label Try Orchard first' "$LOG"
[[ "$(grep -c '^kdialog ' "$LOG")" -eq 1 ]]
[[ "$(grep -c '^installer$' "$LOG" || true)" -eq 0 ]]

# The marker prevents repeated prompts but leaves the launcher in place.
HOME="$TEST_ROOT/home" \
PATH="$BIN_DIR:$PATH" \
ORCHARD_ARCHISO_ROOT="$ARCHISO_ROOT" \
ORCHARD_INSTALL_APPLICATION="$APPLICATION" \
ORCHARD_INSTALLER="$INSTALLER" \
ORCHARD_WELCOME_MARKER="$MARKER" \
ORCHARD_DESKTOP_DIR="$DESKTOP" \
ORCHARD_PROMPT_DELAY=0 \
  "$SCRIPT"
[[ "$(grep -c '^kdialog ' "$LOG")" -eq 1 ]]

rm -f -- "$MARKER"
HOME="$TEST_ROOT/home" \
PATH="$BIN_DIR:$PATH" \
KDIALOG_RESULT=0 \
ORCHARD_ARCHISO_ROOT="$ARCHISO_ROOT" \
ORCHARD_INSTALL_APPLICATION="$APPLICATION" \
ORCHARD_INSTALLER="$INSTALLER" \
ORCHARD_WELCOME_MARKER="$MARKER" \
ORCHARD_DESKTOP_DIR="$DESKTOP" \
ORCHARD_PROMPT_DELAY=0 \
  "$SCRIPT"
grep -qxF installer "$LOG"

echo "Live welcome tests passed."
