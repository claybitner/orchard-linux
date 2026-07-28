#!/usr/bin/env bash
set -Eeuo pipefail

UPSTREAM="${1:?usage: apply-overlay.sh UPSTREAM [ISO_NAME] [PROFILE]}"
ISO_NAME="${2:-macbook-cachyos}"
PROFILE="${3:-desktop}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

ARCHISO="$UPSTREAM/archiso"
[[ -d "$ARCHISO" ]] || {
  echo "Missing expected upstream directory: $ARCHISO" >&2
  exit 1
}

if [[ ! "$ISO_NAME" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "Invalid ISO name '$ISO_NAME'; use lowercase letters, digits, dots, dashes, or underscores." >&2
  exit 2
fi

echo "Applying MacBook overlay to: $ARCHISO"
rsync -a "$ROOT/overlay/airootfs/" "$ARCHISO/airootfs/"

"$ROOT/scripts/patch-package-list.sh" "$ARCHISO" "$PROFILE"

PROFILEDEF="$ARCHISO/profiledef.sh"
if [[ ! -f "$PROFILEDEF" ]]; then
  echo "Missing expected upstream profile: $PROFILEDEF" >&2
  exit 1
fi
if [[ "$(grep -c '^iso_name=' "$PROFILEDEF")" -ne 1 ]]; then
  echo "Expected exactly one iso_name assignment in $PROFILEDEF; refusing to patch it." >&2
  exit 1
fi
PROFILEDEF_TMP="$(mktemp "${PROFILEDEF}.XXXXXX")"
trap 'rm -f -- "$PROFILEDEF_TMP"' EXIT
awk -v iso_name="$ISO_NAME" '
  /^iso_name=/ { print "iso_name=\"" iso_name "\""; next }
  { print }
' "$PROFILEDEF" > "$PROFILEDEF_TMP"
mv -f -- "$PROFILEDEF_TMP" "$PROFILEDEF"
trap - EXIT

# Ensure executable bits survive archive extraction.
find "$ARCHISO/airootfs/usr/local/bin" -type f -exec chmod 0755 {} +
find "$ARCHISO/airootfs/usr/lib/macbook-cachyos" -type f -exec chmod 0755 {} +
chmod 0644 "$ARCHISO/airootfs/etc/systemd/system/macbook-firstboot.service"

echo "Overlay applied."
