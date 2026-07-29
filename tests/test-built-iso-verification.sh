#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

write_success_log() {
  local log_file="${1:?missing log file}"
  local profile="${2:?missing profile}"
  cat > "$log_file" <<'EOF'
Writing to 'stdio:/tmp/out/macbook-cachyos.iso' completed successfully.
==> Done [Build ISO] macbook-cachyos.iso
EOF
  printf '==> Finished building [%s]\n' "$profile" >> "$log_file"
}

mkdir -p "$TEST_ROOT/success"
printf 'test iso\n' > "$TEST_ROOT/success/macbook-cachyos.iso"
printf 'linux-cachyos\n' > "$TEST_ROOT/success/macbook-cachyos.pkgs.txt"
write_success_log "$TEST_ROOT/success.log" success

MACBOOK_MIN_ISO_BYTES=1 \
  "$ROOT/scripts/verify-built-iso.sh" \
  "$TEST_ROOT/success" \
  "$TEST_ROOT/success.log"
(
  cd "$TEST_ROOT/success"
  sha256sum --check SHA256SUMS
)

mkdir -p "$TEST_ROOT/missing-marker"
printf 'test iso\n' > "$TEST_ROOT/missing-marker/macbook-cachyos.iso"
printf 'linux-cachyos\n' > "$TEST_ROOT/missing-marker/macbook-cachyos.pkgs.txt"
printf '%s\n' 'incomplete build' > "$TEST_ROOT/missing-marker.log"
if MACBOOK_MIN_ISO_BYTES=1 \
  "$ROOT/scripts/verify-built-iso.sh" \
  "$TEST_ROOT/missing-marker" \
  "$TEST_ROOT/missing-marker.log"; then
  echo "Verification accepted a build log without success markers." >&2
  exit 1
fi

mkdir -p "$TEST_ROOT/multiple-images"
printf 'first\n' > "$TEST_ROOT/multiple-images/first.iso"
printf 'second\n' > "$TEST_ROOT/multiple-images/second.iso"
printf 'linux-cachyos\n' > "$TEST_ROOT/multiple-images/macbook-cachyos.pkgs.txt"
write_success_log "$TEST_ROOT/multiple-images.log" multiple-images
if MACBOOK_MIN_ISO_BYTES=1 \
  "$ROOT/scripts/verify-built-iso.sh" \
  "$TEST_ROOT/multiple-images" \
  "$TEST_ROOT/multiple-images.log"; then
  echo "Verification accepted multiple ISO files." >&2
  exit 1
fi

echo "Built ISO verification tests passed."
