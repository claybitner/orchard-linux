#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home"

cat > "$TEST_ROOT/bin/xinput" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

case "${1:-}" in
  list)
    if [[ "${2:-}" == --id-only && "${3:-}" == bcm5974 ]]; then
      echo 8
    elif [[ "${2:-}" == -props ]]; then
      echo "libinput Scrolling Pixel Distance (302): 15"
    fi
    ;;
  list-props)
    echo "libinput Scrolling Pixel Distance (302): 15"
    ;;
  set-prop)
    printf '%s\n' "$*" >> "$TRACKPAD_TEST_LOG"
    ;;
esac
EOF

cat > "$TEST_ROOT/bin/kreadconfig6" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)
      key="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

case "$key" in
  ScrollSpeed) echo fast ;;
esac
EOF

chmod 0755 "$TEST_ROOT/bin/xinput" "$TEST_ROOT/bin/kreadconfig6"

export HOME="$TEST_ROOT/home"
export PATH="$TEST_ROOT/bin:/usr/bin:/bin"
export TRACKPAD_TEST_LOG="$TEST_ROOT/xinput.log"
export XDG_SESSION_TYPE=x11

"$ROOT/overlay/airootfs/usr/local/bin/orchard-trackpad" apply

grep -qxF \
  'set-prop 8 libinput Scrolling Pixel Distance 28' \
  "$TRACKPAD_TEST_LOG"

echo "Trackpad-settings tests passed."
