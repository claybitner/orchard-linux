#!/usr/bin/env bash
set -Eeuo pipefail

UPSTREAM="${1:?usage: validate.sh UPSTREAM [PROFILE]}"
PROFILE="${2:-desktop}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHISO="$UPSTREAM/archiso"
PROFILEDEF="$ARCHISO/profiledef.sh"
UTIL_ISO="$UPSTREAM/util-iso.sh"

# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

fail=0
required_files=(
  "$ARCHISO/airootfs/etc/pacman.d/hooks/99-macbook-calamares.hook"
  "$ARCHISO/airootfs/usr/local/bin/macbook-hardware-report"
  "$ARCHISO/airootfs/usr/local/bin/macbook-diagnostic-bundle"
  "$ARCHISO/airootfs/usr/local/bin/macbook-optional-theme"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/firstboot"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/patch-calamares"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/setup-plasma"
  "$ARCHISO/airootfs/etc/systemd/system/macbook-firstboot.service"
)
executable_overlay_paths=(
  /usr/local/bin/macbook-hardware-report
  /usr/local/bin/macbook-diagnostic-bundle
  /usr/local/bin/macbook-optional-theme
  /usr/lib/macbook-cachyos/firstboot
  /usr/lib/macbook-cachyos/patch-calamares
  /usr/lib/macbook-cachyos/setup-plasma
  /usr/lib/macbook-cachyos/plasma-layout-once
)

for f in "${required_files[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing: $f" >&2
    fail=1
  fi
done

for executable_path in "${executable_overlay_paths[@]}"; do
  permission_rule="  [\"$executable_path\"]=\"0:0:755\" # orchard-linux: executable overlay"
  if [[ "$(grep -cFx "$permission_rule" "$PROFILEDEF")" -ne 1 ]]; then
    echo "ArchISO executable permission rule missing or duplicated: $executable_path" >&2
    fail=1
  fi
done

CALAMARES_HOOK="$ARCHISO/airootfs/etc/pacman.d/hooks/99-macbook-calamares.hook"
if ! grep -qxF \
  'Exec = /usr/bin/bash /usr/lib/macbook-cachyos/patch-calamares' \
  "$CALAMARES_HOOK"; then
  echo "Calamares hook does not invoke its patch through Bash." >&2
  fail=1
fi

CALAMARES_PATCH="$ARCHISO/airootfs/usr/lib/macbook-cachyos/patch-calamares"
for pkg in \
  broadcom-wl-dkms \
  dkms \
  linux-cachyos-headers \
  linux-cachyos-lts-headers \
  power-profiles-daemon; do
  grep -qF "$pkg" "$CALAMARES_PATCH" || {
    echo "Installed-system package not present in Calamares patch: $pkg" >&2
    fail=1
  }
done

for copied_file in \
  /etc/systemd/system/macbook-firstboot.service \
  /usr/lib/macbook-cachyos/firstboot \
  /usr/local/bin/macbook-diagnostic-bundle; do
  grep -qF "\"$copied_file\"" "$CALAMARES_PATCH" || {
    echo "Installed-system overlay file not copied by Calamares patch: $copied_file" >&2
    fail=1
  }
done

if ! grep -qE '^[[:space:]]+- name: "macbook-firstboot\.service"$' \
  "$CALAMARES_PATCH"; then
  echo "Calamares patch does not enable macbook-firstboot.service." >&2
  fail=1
fi

if ! PKGLIST="$(find_profile_package_list "$ARCHISO" "$PROFILE")"; then
  echo "Unable to validate package list." >&2
  fail=1
else
  for pkg in broadcom-wl-dkms dkms networkmanager intel-ucode power-profiles-daemon; do
    grep -qxF "$pkg" "$PKGLIST" || {
      echo "Package not present: $pkg" >&2
      fail=1
    }
  done

  while IFS= read -r kernel; do
    grep -qxF "${kernel}-headers" "$PKGLIST" || {
      echo "Headers not present for kernel package: $kernel" >&2
      fail=1
    }
  done < <(list_kernel_packages "$PKGLIST")

  for forbidden in mbpfan tlp; do
    if grep -qxF "$forbidden" "$PKGLIST"; then
      echo "Unsupported/conflicting package present: $forbidden" >&2
      fail=1
    fi
  done
fi

if grep -RqE 'systemctl enable .* (tlp|mbpfan)\.service' \
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos"; then
  echo "TLP or mbpfan is enabled despite using power-profiles-daemon." >&2
  fail=1
fi

if [[ ! -f "$PROFILEDEF" ]] || [[ ! -f "$UTIL_ISO" ]]; then
  echo "Missing upstream ISO naming files." >&2
  fail=1
else
  ISO_NAME="$(sed -nE 's/^iso_name="([^"]+)"$/\1/p' "$PROFILEDEF")"
  if [[ -z "$ISO_NAME" ]]; then
    echo "Unable to read the customized iso_name from $PROFILEDEF." >&2
    fail=1
  else
    grep -qxF \
      "    vars+=(\"$ISO_NAME\") # orchard-linux: ISO filename prefix" \
      "$UTIL_ISO" || {
        echo "CachyOS final ISO filename prefix does not match iso_name." >&2
        fail=1
      }
    grep -qF \
      "    mv \"\$outFolder/\$_profile/$ISO_NAME-\$(date " \
      "$UTIL_ISO" || {
        echo "CachyOS raw ISO filename does not match iso_name." >&2
        fail=1
      }
  fi
fi

if [[ $fail -ne 0 ]]; then
  echo "Validation failed." >&2
  exit 1
fi

echo "Validation passed."
