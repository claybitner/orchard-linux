#!/usr/bin/env bash
set -Eeuo pipefail

UPSTREAM="${1:?usage: apply-overlay.sh UPSTREAM [ISO_NAME]}"
ISO_NAME="${2:-macbook-cachyos}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

ARCHISO="$UPSTREAM/archiso"
[[ -d "$ARCHISO" ]] || {
  echo "Missing expected upstream directory: $ARCHISO" >&2
  exit 1
}

echo "Applying MacBook overlay to: $ARCHISO"
rsync -a "$ROOT/overlay/airootfs/" "$ARCHISO/airootfs/"

"$ROOT/scripts/patch-package-list.sh" "$ARCHISO"

# Best-effort branding. We deliberately do not fail if upstream changes this.
PROFILEDEF="$ARCHISO/profiledef.sh"
if [[ -f "$PROFILEDEF" ]]; then
  sed -i -E \
    "s/^(iso_name=).*/\1\"${ISO_NAME}\"/" \
    "$PROFILEDEF" || true
fi

# Ensure executable bits survive archive extraction.
find "$ARCHISO/airootfs/usr/local/bin" -type f -exec chmod 0755 {} +
find "$ARCHISO/airootfs/usr/lib/macbook-cachyos" -type f -exec chmod 0755 {} +
chmod 0644 "$ARCHISO/airootfs/etc/systemd/system/macbook-firstboot.service"

echo "Overlay applied."
