#!/usr/bin/env bash
set -Eeuo pipefail

UPSTREAM="${1:?usage: validate.sh UPSTREAM [PROFILE]}"
PROFILE="${2:-desktop}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHISO="$UPSTREAM/archiso"

# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

fail=0
required_files=(
  "$ARCHISO/airootfs/etc/calamares/modules/pacstrap.conf"
  "$ARCHISO/airootfs/etc/calamares/modules/services-systemd.conf"
  "$ARCHISO/airootfs/usr/local/bin/macbook-hardware-report"
  "$ARCHISO/airootfs/usr/local/bin/macbook-diagnostic-bundle"
  "$ARCHISO/airootfs/usr/local/bin/macbook-optional-theme"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/firstboot"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/setup-plasma"
  "$ARCHISO/airootfs/etc/systemd/system/macbook-firstboot.service"
)

for f in "${required_files[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing: $f" >&2
    fail=1
  fi
done

CALAMARES_PACSTRAP="$ARCHISO/airootfs/etc/calamares/modules/pacstrap.conf"
CALAMARES_SERVICES="$ARCHISO/airootfs/etc/calamares/modules/services-systemd.conf"
for pkg in \
  broadcom-wl-dkms \
  dkms \
  linux-cachyos-headers \
  linux-cachyos-lts-headers \
  power-profiles-daemon; do
  grep -qE "^[[:space:]]+- ${pkg}$" "$CALAMARES_PACSTRAP" || {
    echo "Installed-system package not present in Calamares pacstrap: $pkg" >&2
    fail=1
  }
done

for copied_file in \
  /etc/systemd/system/macbook-firstboot.service \
  /usr/lib/macbook-cachyos/firstboot \
  /usr/local/bin/macbook-diagnostic-bundle; do
  grep -qF "\"$copied_file\"" "$CALAMARES_PACSTRAP" || {
    echo "Installed-system overlay file not copied by Calamares: $copied_file" >&2
    fail=1
  }
done

if ! grep -qE '^[[:space:]]+- name: "macbook-firstboot\.service"$' \
  "$CALAMARES_SERVICES"; then
  echo "Calamares does not enable macbook-firstboot.service." >&2
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

if [[ $fail -ne 0 ]]; then
  echo "Validation failed." >&2
  exit 1
fi

echo "Validation passed."
