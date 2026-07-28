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

# Remove exact files from earlier overlay revisions. The Calamares files are
# removed only when they carry this project's old marker; current mkarchiso
# rejects package-owned files that exist before package installation.
rm -f -- \
  "$ARCHISO/airootfs/etc/modprobe.d/macbook-broadcom.conf" \
  "$ARCHISO/airootfs/etc/tlp.d/20-macbook.conf"
for stale_calamares in \
  "$ARCHISO/airootfs/etc/calamares/modules/pacstrap.conf" \
  "$ARCHISO/airootfs/etc/calamares/modules/services-systemd.conf"; do
  if [[ -f "$stale_calamares" ]] &&
    grep -qF 'extended for Intel MacBooks' "$stale_calamares"; then
    rm -f -- "$stale_calamares"
  fi
done

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

# CachyOS' wrapper renames the raw mkarchiso output after the build. Keep that
# exact, verified integration in sync with the profile's customized iso_name.
UTIL_ISO="$UPSTREAM/util-iso.sh"
[[ -f "$UTIL_ISO" ]] || {
  echo "Missing expected upstream build helper: $UTIL_ISO" >&2
  exit 1
}

PREFIX_MARKER='# orchard-linux: ISO filename prefix'
MOVE_MARKER='# orchard-linux: raw ISO filename'
DEFAULT_PREFIX='    vars+=("cachyos")'
DEFAULT_MOVE='    mv "$outFolder/$_profile/cachyos-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)-x86_64.iso" "$outFolder/$_profile/${iso_file}"'

if grep -qF "$PREFIX_MARKER" "$UTIL_ISO"; then
  [[ "$(grep -cF "$PREFIX_MARKER" "$UTIL_ISO")" -eq 1 ]] || {
    echo "Expected exactly one marked ISO filename prefix in $UTIL_ISO." >&2
    exit 1
  }
elif [[ "$(grep -cFx "$DEFAULT_PREFIX" "$UTIL_ISO")" -ne 1 ]]; then
  echo "Upstream ISO filename prefix changed in $UTIL_ISO; refusing to patch it." >&2
  exit 1
fi

if grep -qF "$MOVE_MARKER" "$UTIL_ISO"; then
  [[ "$(grep -cF "$MOVE_MARKER" "$UTIL_ISO")" -eq 1 ]] || {
    echo "Expected exactly one marked raw ISO filename in $UTIL_ISO." >&2
    exit 1
  }
elif [[ "$(grep -cFx "$DEFAULT_MOVE" "$UTIL_ISO")" -ne 1 ]]; then
  echo "Upstream raw ISO filename changed in $UTIL_ISO; refusing to patch it." >&2
  exit 1
fi

UTIL_ISO_TMP="$(mktemp "${UTIL_ISO}.XXXXXX")"
trap 'rm -f -- "$UTIL_ISO_TMP"' EXIT
awk \
  -v iso_name="$ISO_NAME" \
  -v default_prefix="$DEFAULT_PREFIX" \
  -v prefix_marker="$PREFIX_MARKER" \
  -v default_move="$DEFAULT_MOVE" \
  -v move_marker="$MOVE_MARKER" '
  $0 == default_prefix || index($0, prefix_marker) {
    print "    vars+=(\"" iso_name "\") " prefix_marker
    next
  }
  $0 == default_move || index($0, move_marker) {
    print "    mv \"$outFolder/$_profile/" iso_name \
      "-$(date --date=\"@${SOURCE_DATE_EPOCH:-$(date +%s)}\" +%Y.%m.%d)-x86_64.iso\" " \
      "\"$outFolder/$_profile/${iso_file}\" " move_marker
    next
  }
  { print }
' "$UTIL_ISO" > "$UTIL_ISO_TMP"
mv -f -- "$UTIL_ISO_TMP" "$UTIL_ISO"
trap - EXIT

# Ensure executable bits survive archive extraction.
find "$ARCHISO/airootfs/usr/local/bin" -type f -exec chmod 0755 {} +
find "$ARCHISO/airootfs/usr/lib/macbook-cachyos" -type f -exec chmod 0755 {} +
chmod 0644 "$ARCHISO/airootfs/etc/systemd/system/macbook-firstboot.service"

echo "Overlay applied."
