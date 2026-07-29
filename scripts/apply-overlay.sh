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

# mkarchiso normalizes files from airootfs unless their final ownership and
# mode are declared here. Source-tree executable bits alone are not sufficient.
# Keep this list explicit so live helpers and the copies installed by Calamares
# remain executable.
EXECUTABLE_OVERLAY_PATHS=(
  /usr/local/bin/macbook-hardware-report
  /usr/local/bin/macbook-diagnostic-bundle
  /usr/local/bin/macbook-optional-theme
  /usr/local/bin/orchard-trackpad
  /usr/lib/macbook-cachyos/build-rounded-corners
  /usr/lib/macbook-cachyos/firstboot
  /usr/lib/macbook-cachyos/patch-calamares
  /usr/lib/macbook-cachyos/setup-plasma
  /usr/lib/macbook-cachyos/plasma-layout-once
)

if [[ "$(grep -c '^file_permissions=($' "$PROFILEDEF")" -ne 1 ]]; then
  echo "Expected exactly one file_permissions array in $PROFILEDEF; refusing to patch it." >&2
  exit 1
fi

PROFILEDEF_PERMISSIONS_TMP="$(mktemp "${PROFILEDEF}.permissions.XXXXXX")"
trap 'rm -f -- "$PROFILEDEF_PERMISSIONS_TMP"' EXIT
awk '
  BEGIN {
    marker = " # orchard-linux: executable overlay"
    paths[1] = "/usr/local/bin/macbook-hardware-report"
    paths[2] = "/usr/local/bin/macbook-diagnostic-bundle"
    paths[3] = "/usr/local/bin/macbook-optional-theme"
    paths[4] = "/usr/local/bin/orchard-trackpad"
    paths[5] = "/usr/lib/macbook-cachyos/build-rounded-corners"
    paths[6] = "/usr/lib/macbook-cachyos/firstboot"
    paths[7] = "/usr/lib/macbook-cachyos/patch-calamares"
    paths[8] = "/usr/lib/macbook-cachyos/setup-plasma"
    paths[9] = "/usr/lib/macbook-cachyos/plasma-layout-once"
  }
  /^file_permissions=\($/ {
    in_permissions = 1
    print
    next
  }
  in_permissions && /^\)$/ {
    for (i = 1; i <= 9; i++) {
      print "  [\"" paths[i] "\"]=\"0:0:755\"" marker
    }
    in_permissions = 0
    closed_permissions = 1
    print
    next
  }
  in_permissions {
    for (i = 1; i <= 9; i++) {
      prefix = "[\"" paths[i] "\"]="
      line = $0
      sub(/^[[:space:]]*/, "", line)
      if (index(line, prefix) == 1) {
        next
      }
    }
  }
  { print }
  END {
    if (!closed_permissions) {
      exit 3
    }
  }
' "$PROFILEDEF" > "$PROFILEDEF_PERMISSIONS_TMP" || {
  echo "Unable to patch the file_permissions array in $PROFILEDEF." >&2
  exit 1
}
mv -f -- "$PROFILEDEF_PERMISSIONS_TMP" "$PROFILEDEF"
trap - EXIT

for executable_path in "${EXECUTABLE_OVERLAY_PATHS[@]}"; do
  permission_rule="  [\"$executable_path\"]=\"0:0:755\" # orchard-linux: executable overlay"
  if [[ "$(grep -cFx "$permission_rule" "$PROFILEDEF")" -ne 1 ]]; then
    echo "Executable permission rule missing or duplicated for $executable_path." >&2
    exit 1
  fi
done

# CachyOS' wrapper renames the raw mkarchiso output after the build. Keep that
# exact, verified integration in sync with the profile's customized iso_name.
UTIL_ISO="$UPSTREAM/util-iso.sh"
[[ -f "$UTIL_ISO" ]] || {
  echo "Missing expected upstream build helper: $UTIL_ISO" >&2
  exit 1
}
BUILDISO="$UPSTREAM/buildiso.sh"
[[ -f "$BUILDISO" ]] || {
  echo "Missing expected upstream build entry point: $BUILDISO" >&2
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

# CachyOS currently installs an unconditional EXIT trap that reports a normal,
# successful return from run_build as an unknown error. Depending on the Bash
# version, that false error can also become exit status 1 after the finished ISO
# has been removed from the work directory. Keep ERR and signal handling intact,
# but make the EXIT handler run only for a genuinely nonzero status.
EXIT_TRAP_MARKER='# orchard-linux: success-aware exit trap'
DEFAULT_EXIT_TRAP="$(cat <<'EOF'
trap 'trap_exit EXIT "$(gettext "An unknown error has occurred. Exiting...")"' EXIT
EOF
)"
PATCHED_EXIT_TRAP="$(cat <<'EOF'
trap 'status=$?; (( status == 0 )) || trap_exit EXIT "$(gettext "An unknown error has occurred. Exiting...")"' EXIT # orchard-linux: success-aware exit trap
EOF
)"

if grep -qF "$EXIT_TRAP_MARKER" "$BUILDISO"; then
  if [[ "$(grep -cF "$EXIT_TRAP_MARKER" "$BUILDISO")" -ne 1 ]]; then
    echo "Expected exactly one marked EXIT trap in $BUILDISO." >&2
    exit 1
  fi
elif [[ "$(grep -cFx "$DEFAULT_EXIT_TRAP" "$BUILDISO")" -ne 1 ]]; then
  echo "Upstream EXIT trap changed in $BUILDISO; refusing to patch it." >&2
  exit 1
fi

BUILDISO_TMP="$(mktemp "${BUILDISO}.XXXXXX")"
trap 'rm -f -- "$BUILDISO_TMP"' EXIT
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "$DEFAULT_EXIT_TRAP" || "$line" == *"$EXIT_TRAP_MARKER" ]]; then
    printf '%s\n' "$PATCHED_EXIT_TRAP"
  else
    printf '%s\n' "$line"
  fi
done < "$BUILDISO" > "$BUILDISO_TMP"
chmod 0755 "$BUILDISO_TMP"
mv -f -- "$BUILDISO_TMP" "$BUILDISO"
trap - EXIT

# Ensure only actual programs are executable. The same directory also contains
# CSS, XML and service configuration consumed as data.
for executable_path in "${EXECUTABLE_OVERLAY_PATHS[@]}"; do
  chmod 0755 "$ARCHISO/airootfs$executable_path"
done
chmod 0644 "$ARCHISO/airootfs/etc/systemd/system/macbook-firstboot.service"

echo "Overlay applied."
