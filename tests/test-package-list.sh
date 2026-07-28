#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

CURRENT="$TEST_ROOT/current"
mkdir -p "$CURRENT"
cat > "$CURRENT/packages_desktop.x86_64" <<'EOF'
linux-cachyos
linux-cachyos-lts
linux-cachyos-nvidia-open
linux-cachyos-lts-zfs
power-profiles-daemon
EOF

"$ROOT/scripts/patch-package-list.sh" "$CURRENT" desktop

for expected in \
  broadcom-wl-dkms \
  linux-cachyos-headers \
  linux-cachyos-lts-headers \
  power-profiles-daemon; do
  grep -qxF "$expected" "$CURRENT/packages_desktop.x86_64"
done

for unexpected in \
  linux-cachyos-nvidia-open-headers \
  linux-cachyos-lts-zfs-headers \
  mbpfan \
  tlp; do
  if grep -qxF "$unexpected" "$CURRENT/packages_desktop.x86_64"; then
    echo "Unexpected package added: $unexpected" >&2
    exit 1
  fi
done

cp "$CURRENT/packages_desktop.x86_64" "$TEST_ROOT/first-pass"
"$ROOT/scripts/patch-package-list.sh" "$CURRENT" desktop
cmp "$TEST_ROOT/first-pass" "$CURRENT/packages_desktop.x86_64"

LEGACY="$TEST_ROOT/legacy"
mkdir -p "$LEGACY"
printf '%s\n' linux-zen > "$LEGACY/packages.x86_64"
"$ROOT/scripts/patch-package-list.sh" "$LEGACY" desktop
grep -qxF linux-zen-headers "$LEGACY/packages.x86_64"

UNKNOWN="$TEST_ROOT/unknown"
mkdir -p "$UNKNOWN"
printf '%s\n' linux > "$UNKNOWN/new-package-layout.txt"
if "$ROOT/scripts/patch-package-list.sh" "$UNKNOWN" desktop 2>/dev/null; then
  echo "Unknown upstream layout was accepted." >&2
  exit 1
fi

echo "Package-list tests passed."
