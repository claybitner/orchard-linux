#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM=""
CLONE=0
ISO_NAME="macbook-cachyos"
PROFILE="desktop"
NO_BUILD=0

usage() {
  cat <<EOF
Usage: sudo $0 [options]

Options:
  --upstream PATH       Existing CachyOS-Live-ISO checkout
  --clone-upstream      Clone upstream into ./work/CachyOS-Live-ISO
  --name NAME           ISO name label (default: macbook-cachyos)
  --profile PROFILE     CachyOS profile (default: desktop)
  --no-build            Apply and validate only
  -h, --help            Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream) UPSTREAM="${2:?missing path}"; shift 2 ;;
    --clone-upstream) CLONE=1; shift ;;
    --name) ISO_NAME="${2:?missing name}"; shift 2 ;;
    --profile) PROFILE="${2:?missing profile}"; shift 2 ;;
    --no-build) NO_BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run as root; archiso requires root privileges." >&2
  exit 1
fi

for cmd in bash git rsync sed grep find awk; do
  command -v "$cmd" >/dev/null || {
    echo "Missing command: $cmd" >&2
    exit 1
  }
done

if [[ $CLONE -eq 1 ]]; then
  UPSTREAM="$ROOT/work/CachyOS-Live-ISO"
  if [[ ! -d "$UPSTREAM/.git" ]]; then
    mkdir -p "$(dirname "$UPSTREAM")"
    git clone --depth 1 https://github.com/CachyOS/CachyOS-Live-ISO.git "$UPSTREAM"
  else
    git -C "$UPSTREAM" pull --ff-only
  fi
fi

if [[ -z "$UPSTREAM" ]]; then
  echo "Supply --upstream PATH or --clone-upstream." >&2
  exit 2
fi

UPSTREAM="$(realpath "$UPSTREAM")"
[[ -x "$UPSTREAM/buildiso.sh" ]] || {
  echo "Not a CachyOS-Live-ISO checkout: $UPSTREAM" >&2
  exit 1
}

"$ROOT/scripts/apply-overlay.sh" "$UPSTREAM" "$ISO_NAME" "$PROFILE"
"$ROOT/scripts/validate.sh" "$UPSTREAM" "$PROFILE"

if [[ $NO_BUILD -eq 1 ]]; then
  echo "Overlay applied and validated. Build skipped."
  exit 0
fi

echo "Starting CachyOS ISO build..."
cd "$UPSTREAM"
./buildiso.sh -p "$PROFILE" -v -w

echo
echo "Build complete. Inspect: $UPSTREAM/out"
