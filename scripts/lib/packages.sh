#!/usr/bin/env bash

find_profile_package_list() {
  local archiso="${1:?missing archiso directory}"
  local profile="${2:?missing profile}"
  local current="$archiso/packages_${profile}.x86_64"
  local legacy="$archiso/packages.x86_64"
  local legacy_desktop="$archiso/Packages-Desktop"

  if [[ -f "$current" ]]; then
    printf '%s\n' "$current"
    return 0
  fi

  if [[ -f "$legacy" ]]; then
    printf '%s\n' "$legacy"
    return 0
  fi

  if [[ "$profile" == "desktop" && -f "$legacy_desktop" ]]; then
    printf '%s\n' "$legacy_desktop"
    return 0
  fi

  echo "Could not locate the '$profile' ISO package list under $archiso." >&2
  echo "Expected one of:" >&2
  echo "  $current" >&2
  echo "  $legacy" >&2
  if [[ "$profile" == "desktop" ]]; then
    echo "  $legacy_desktop" >&2
  fi
  echo "Upstream package-list layout may have changed; refusing to guess." >&2
  return 1
}

list_kernel_packages() {
  local package_list="${1:?missing package list}"
  local package

  while IFS= read -r package; do
    case "$package" in
      linux|linux-lts|linux-zen|linux-hardened)
        printf '%s\n' "$package"
        ;;
      linux-cachyos|linux-cachyos-*)
        case "$package" in
          *-headers|*-dbg|*-nvidia|*-nvidia-open|*-r8125|*-zfs)
            ;;
          *)
            printf '%s\n' "$package"
            ;;
        esac
        ;;
    esac
  done < <(
    awk '!/^[[:space:]]*(#|$)/ { print $1 }' "$package_list" | sort -u
  )
}
