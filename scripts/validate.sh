#!/usr/bin/env bash
set -Eeuo pipefail

UPSTREAM="${1:?usage: validate.sh UPSTREAM}"
ARCHISO="$UPSTREAM/archiso"

fail=0
required_files=(
  "$ARCHISO/airootfs/usr/local/bin/macbook-hardware-report"
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

PKGLIST="$(find "$ARCHISO" -maxdepth 3 -type f -name 'packages.x86_64' | head -1)"
if [[ -z "$PKGLIST" ]]; then
  echo "Unable to validate package list." >&2
  fail=1
else
  for pkg in broadcom-wl-dkms dkms networkmanager intel-ucode; do
    grep -qxF "$pkg" "$PKGLIST" || {
      echo "Package not present: $pkg" >&2
      fail=1
    }
  done
fi

if [[ $fail -ne 0 ]]; then
  echo "Validation failed." >&2
  exit 1
fi

echo "Validation passed."
