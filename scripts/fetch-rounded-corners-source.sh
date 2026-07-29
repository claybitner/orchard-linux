#!/usr/bin/env bash
set -Eeuo pipefail

DESTINATION="${1:?usage: fetch-rounded-corners-source.sh DESTINATION_DIR}"
COMMIT=46b943637f9c1313f2a489c1d4b5e7fa08e01fc1
ARCHIVE="KDE-Rounded-Corners-$COMMIT.tar.gz"
SOURCE_URL="https://github.com/matinlotfali/KDE-Rounded-Corners/archive/$COMMIT.tar.gz"
EXPECTED_SHA256=1367160e61371f00a2ab95981623f631e20b123e55232ed727d2e4f6467560c8
SOURCE_ARCHIVE="${MACBOOK_ROUNDED_CORNERS_ARCHIVE:-}"

for command in awk install mktemp sha256sum; do
  command -v "$command" >/dev/null || {
    echo "Missing command required to stage rounded-corner source: $command" >&2
    exit 1
  }
done

install -d -m 0755 "$DESTINATION"
target="$DESTINATION/$ARCHIVE"
if [[ -f "$target" ]] &&
  [[ "$(sha256sum "$target" | awk '{print $1}')" == "$EXPECTED_SHA256" ]]; then
  echo "Rounded-corner source is already staged and verified."
  exit 0
fi

temporary="$(mktemp "${target}.XXXXXX")"
trap 'rm -f -- "$temporary"' EXIT

if [[ -n "$SOURCE_ARCHIVE" ]]; then
  install -m 0644 "$SOURCE_ARCHIVE" "$temporary"
else
  command -v curl >/dev/null || {
    echo "Missing command required to fetch rounded-corner source: curl" >&2
    exit 1
  }
  curl \
    --fail \
    --location \
    --retry 3 \
    --retry-all-errors \
    --output "$temporary" \
    "$SOURCE_URL"
fi

if [[ "$(sha256sum "$temporary" | awk '{print $1}')" != "$EXPECTED_SHA256" ]]; then
  echo "Rounded-corner source checksum verification failed." >&2
  exit 1
fi

chmod 0644 "$temporary"
mv -f -- "$temporary" "$target"
trap - EXIT
echo "Rounded-corner source staged: $target"
