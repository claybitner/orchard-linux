#!/usr/bin/env bash
set -Eeuo pipefail

ARCHISO="${1:?usage: patch-package-list.sh ARCHISO_DIR}"

mapfile -t CANDIDATES < <(
  find "$ARCHISO" -maxdepth 3 -type f \
    \( -name 'packages.x86_64' -o -name 'packages.*' -o -name 'Packages-Desktop' \) \
    | sort
)

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "Could not locate an ISO package list under $ARCHISO" >&2
  exit 1
fi

# Prefer the main archiso list.
PKGLIST=""
for f in "${CANDIDATES[@]}"; do
  if [[ "$f" == "$ARCHISO/packages.x86_64" ]]; then
    PKGLIST="$f"
    break
  fi
done
PKGLIST="${PKGLIST:-${CANDIDATES[0]}}"

echo "Using package list: $PKGLIST"

PACKAGES=(
  broadcom-wl-dkms
  dkms
  linux-firmware
  wireless-regdb
  networkmanager
  iwd
  iw
  rfkill
  pciutils
  usbutils
  dmidecode
  intel-ucode
  thermald
  tlp
  mbpfan
  fwupd
)

append_package() {
  local pkg="$1"
  grep -qxF "$pkg" "$PKGLIST" || printf '%s\n' "$pkg" >> "$PKGLIST"
}

for pkg in "${PACKAGES[@]}"; do
  append_package "$pkg"
done

# DKMS needs headers matching every included kernel. Handle common Arch/CachyOS
# names and avoid accidentally treating an existing -headers package as a kernel.
mapfile -t KERNELS < <(
  grep -Ev '^[[:space:]]*(#|$)' "$PKGLIST" |
    awk '{print $1}' |
    grep -E '^linux($|-lts$|-zen$|-hardened$|-cachyos([_-].*)?$)' |
    grep -v -- '-headers$' |
    sort -u || true
)

if [[ ${#KERNELS[@]} -eq 0 ]]; then
  echo "WARNING: no kernel package was detected. Adding linux-headers as fallback." >&2
  append_package linux-headers
else
  for kernel in "${KERNELS[@]}"; do
    append_package "${kernel}-headers"
  done
fi

sort -u "$PKGLIST" -o "$PKGLIST"
