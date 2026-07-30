#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="${1:?usage: verify-built-iso.sh OUT_DIR BUILD_LOG}"
BUILD_LOG="${2:?usage: verify-built-iso.sh OUT_DIR BUILD_LOG}"
MIN_ISO_BYTES="${MACBOOK_MIN_ISO_BYTES:-1073741824}"
PROFILE="$(basename -- "$OUT_DIR")"

for cmd in find grep sha256sum wc; do
  command -v "$cmd" >/dev/null || {
    echo "Missing command required to verify the ISO: $cmd" >&2
    exit 1
  }
done

[[ -d "$OUT_DIR" ]] || {
  echo "ISO output directory does not exist: $OUT_DIR" >&2
  exit 1
}
[[ -f "$BUILD_LOG" ]] || {
  echo "Build log does not exist: $BUILD_LOG" >&2
  exit 1
}
[[ "$MIN_ISO_BYTES" =~ ^[0-9]+$ ]] || {
  echo "MACBOOK_MIN_ISO_BYTES must be a non-negative integer." >&2
  exit 2
}

required_log_markers=(
  "Rounded corners built for KWin"
  "Orchard live environment prebuilt."
  "Writing to 'stdio:"
  "completed successfully."
  "==> Done [Build ISO]"
  "==> Finished building [$PROFILE]"
)
for marker in "${required_log_markers[@]}"; do
  if ! grep -qF -- "$marker" "$BUILD_LOG"; then
    echo "Build log is missing the required success marker: $marker" >&2
    exit 1
  fi
done

iso_files=()
while IFS= read -r -d '' file; do
  iso_files+=("$file")
done < <(find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -print0)
if [[ ${#iso_files[@]} -ne 1 ]]; then
  echo "Expected exactly one built ISO, found ${#iso_files[@]} in $OUT_DIR." >&2
  exit 1
fi

package_lists=()
while IFS= read -r -d '' file; do
  package_lists+=("$file")
done < <(find "$OUT_DIR" -maxdepth 1 -type f -name '*.pkgs.txt' -print0)
if [[ ${#package_lists[@]} -ne 1 ]]; then
  echo "Expected exactly one package manifest, found ${#package_lists[@]} in $OUT_DIR." >&2
  exit 1
fi
[[ -s "${package_lists[0]}" ]] || {
  echo "Package manifest is empty: ${package_lists[0]}" >&2
  exit 1
}

iso_size="$(wc -c < "${iso_files[0]}")"
iso_size="${iso_size//[[:space:]]/}"
if (( iso_size < MIN_ISO_BYTES )); then
  echo "Built ISO is unexpectedly small: $iso_size bytes (minimum $MIN_ISO_BYTES)." >&2
  exit 1
fi

cd "$OUT_DIR"
iso_name="$(basename -- "${iso_files[0]}")"
sha256sum -- "$iso_name" > SHA256SUMS
sha256sum --check SHA256SUMS

echo "Verified ISO artifact: $OUT_DIR/$iso_name ($iso_size bytes)"
