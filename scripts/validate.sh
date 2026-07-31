#!/usr/bin/env bash
set -Eeuo pipefail

UPSTREAM="${1:?usage: validate.sh UPSTREAM [PROFILE]}"
PROFILE="${2:-desktop}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHISO="$UPSTREAM/archiso"
PROFILEDEF="$ARCHISO/profiledef.sh"
UTIL_ISO="$UPSTREAM/util-iso.sh"
BUILDISO="$UPSTREAM/buildiso.sh"

# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

fail=0
required_files=(
  "$ARCHISO/airootfs/etc/pacman.d/hooks/94-orchard-prebuild-live.hook"
  "$ARCHISO/airootfs/etc/pacman.d/hooks/99-macbook-calamares.hook"
  "$ARCHISO/airootfs/etc/pacman.d/hooks/95-orchard-rounded-corners.hook"
  "$ARCHISO/airootfs/usr/local/bin/macbook-hardware-report"
  "$ARCHISO/airootfs/usr/local/bin/macbook-diagnostic-bundle"
  "$ARCHISO/airootfs/usr/local/bin/macbook-optional-theme"
  "$ARCHISO/airootfs/usr/local/bin/orchard-theme"
  "$ARCHISO/airootfs/usr/local/bin/orchard-trackpad"
  "$ARCHISO/airootfs/etc/xdg/autostart/org.orchard.TrackpadApply.desktop"
  "$ARCHISO/airootfs/etc/environment.d/90-orchard-input.conf"
  "$ARCHISO/airootfs/usr/share/applications/org.orchard.Trackpad.desktop"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/90-no-suspend.conf"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/70-bcm5974-libinput.conf"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/background-setup"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/build-rounded-corners"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/firstboot"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/live-welcome"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/wifi-driver-setup"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/hid-apple.conf"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/keyd-macos.conf"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/patch-calamares"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/prebuild-live-environment"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/setup-plasma"
  "$ARCHISO/airootfs/usr/lib/macbook-cachyos/plasma-layout-once"
  "$ARCHISO/airootfs/usr/share/plasma/look-and-feel/org.orchard.desktop/metadata.json"
  "$ARCHISO/airootfs/usr/share/plasma/look-and-feel/org.orchard.desktop/contents/defaults"
  "$ARCHISO/airootfs/usr/share/plasma/look-and-feel/org.orchard.desktop/contents/splash/Splash.qml"
  "$ARCHISO/airootfs/usr/share/plasma/look-and-feel/org.orchard.dark.desktop/metadata.json"
  "$ARCHISO/airootfs/usr/share/plasma/look-and-feel/org.orchard.dark.desktop/contents/defaults"
  "$ARCHISO/airootfs/usr/share/plasma/look-and-feel/org.orchard.dark.desktop/contents/splash/Splash.qml"
  "$ARCHISO/airootfs/usr/share/applications/org.orchard.Install.desktop"
  "$ARCHISO/airootfs/etc/xdg/autostart/org.orchard.LiveWelcome.desktop"
  "$ARCHISO/airootfs/usr/share/wallpapers/macbook-cachyos/orchard-dusk.svg"
  "$ARCHISO/airootfs/etc/systemd/system/macbook-firstboot.service"
  "$ARCHISO/airootfs/etc/systemd/system/macbook-background-setup.service"
  "$ARCHISO/airootfs/etc/systemd/system/macbook-wifi-driver.service"
)
executable_overlay_paths=(
  /usr/local/bin/macbook-hardware-report
  /usr/local/bin/macbook-diagnostic-bundle
  /usr/local/bin/macbook-optional-theme
  /usr/local/bin/orchard-theme
  /usr/local/bin/orchard-trackpad
  /usr/lib/macbook-cachyos/background-setup
  /usr/lib/macbook-cachyos/build-rounded-corners
  /usr/lib/macbook-cachyos/firstboot
  /usr/lib/macbook-cachyos/live-welcome
  /usr/lib/macbook-cachyos/patch-calamares
  /usr/lib/macbook-cachyos/plasma-layout-once
  /usr/lib/macbook-cachyos/setup-plasma
  /usr/lib/macbook-cachyos/wifi-driver-setup
)

if [[ "${MACBOOK_REQUIRE_ROUNDED_SOURCE:-0}" == 1 ]]; then
  rounded_source="$ARCHISO/airootfs/usr/src/orchard/KDE-Rounded-Corners-46b943637f9c1313f2a489c1d4b5e7fa08e01fc1.tar.gz"
  required_files+=("$rounded_source")
  if [[ -f "$rounded_source" ]] &&
    [[ "$(sha256sum "$rounded_source" | awk '{print $1}')" != \
      1367160e61371f00a2ab95981623f631e20b123e55232ed727d2e4f6467560c8 ]]; then
    echo "Rounded-corner source archive has the wrong checksum." >&2
    fail=1
  fi
fi

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
for calamares_package in cachyos-calamares cachyos-calamares-next; do
  if [[ "$(grep -cxF "Target = $calamares_package" "$CALAMARES_HOOK")" -ne 1 ]]; then
    echo "Calamares hook must patch $calamares_package exactly once." >&2
    fail=1
  fi
done
if ! grep -qxF \
  'Exec = /usr/bin/bash /usr/lib/macbook-cachyos/patch-calamares' \
  "$CALAMARES_HOOK"; then
  echo "Calamares hook does not invoke its patch through Bash." >&2
  fail=1
fi

CALAMARES_PATCH="$ARCHISO/airootfs/usr/lib/macbook-cachyos/patch-calamares"
FIRSTBOOT="$ARCHISO/airootfs/usr/lib/macbook-cachyos/firstboot"
WIFI_DRIVER_SETUP="$ARCHISO/airootfs/usr/lib/macbook-cachyos/wifi-driver-setup"
BACKGROUND_SETUP="$ARCHISO/airootfs/usr/lib/macbook-cachyos/background-setup"
PREBUILD_LIVE="$ARCHISO/airootfs/usr/lib/macbook-cachyos/prebuild-live-environment"
ROUNDED_HOOK="$ARCHISO/airootfs/etc/pacman.d/hooks/95-orchard-rounded-corners.hook"
PREBUILD_HOOK="$ARCHISO/airootfs/etc/pacman.d/hooks/94-orchard-prebuild-live.hook"
BACKGROUND_SERVICE_LINK="$ARCHISO/airootfs/etc/systemd/system/graphical.target.wants/macbook-background-setup.service"
WIFI_SERVICE_LINK="$ARCHISO/airootfs/etc/systemd/system/multi-user.target.wants/macbook-wifi-driver.service"
for pkg in \
  appmenu-gtk-module \
  base-devel \
  broadcom-wl-dkms \
  cmake \
  dkms \
  extra-cmake-modules \
  flatpak \
  linux-cachyos-headers \
  linux-cachyos-lts-headers \
  ffmpegthumbs \
  kdegraphics-thumbnailers \
  keyd \
  kdialog \
  kimageformats \
  kio-extras \
  power-profiles-daemon \
  papirus-icon-theme \
  plasma-browser-integration \
  plasma-x11-session \
  qt6-imageformats \
  sddm \
  shelly \
  ninja \
  vulkan-headers \
  xorg-xinput; do
  grep -qF "$pkg" "$CALAMARES_PATCH" || {
    echo "Installed-system package not present in Calamares patch: $pkg" >&2
    fail=1
  }
done

for expected_firstboot_setting in \
  '/usr/lib/macbook-cachyos/70-bcm5974-libinput.conf' \
  'HOME=/etc/skel /usr/lib/macbook-cachyos/setup-plasma /etc/skel' \
  'systemctl start --no-block' \
  'Prebuilt rounded-corner plugins are missing'; do
  grep -qF "$expected_firstboot_setting" "$FIRSTBOOT" || {
    echo "First-boot integration is absent: $expected_firstboot_setting" >&2
    fail=1
  }
done

for expected_wifi_setting in \
  '14e4:43ba' \
  'brcmfmac_wcc' \
  'brcmfmac feature_disable=0x82000' \
  'Not Apple MacBook hardware'; do
  grep -qF "$expected_wifi_setting" "$WIFI_DRIVER_SETUP" || {
    echo "MacBook Wi-Fi driver selection is incomplete: $expected_wifi_setting" >&2
    fail=1
  }
done

for forbidden_firstboot_work in \
  'flatpak remote-add' \
  '/usr/lib/macbook-cachyos/build-rounded-corners' \
  'macbook-diagnostic-bundle'; do
  if grep -qF "$forbidden_firstboot_work" "$FIRSTBOOT"; then
    echo "Slow work remains in the boot-critical service: $forbidden_firstboot_work" >&2
    fail=1
  fi
done

for expected_background_setting in \
  'build-rounded-corners' \
  'flatpak remote-add' \
  'macbook-diagnostic-bundle' \
  'background-complete-v1'; do
  grep -qF "$expected_background_setting" "$BACKGROUND_SETUP" || {
    echo "Background setup integration is absent: $expected_background_setting" >&2
    fail=1
  }
done

if [[ ! -L "$BACKGROUND_SERVICE_LINK" ]] ||
  [[ "$(readlink "$BACKGROUND_SERVICE_LINK")" != '../macbook-background-setup.service' ]]; then
  echo "Background setup must be enabled by an explicit graphical.target symlink." >&2
  fail=1
fi

if [[ ! -L "$WIFI_SERVICE_LINK" ]] ||
  [[ "$(readlink "$WIFI_SERVICE_LINK")" != '../macbook-wifi-driver.service' ]]; then
  echo "Wi-Fi driver selection must be enabled by an explicit multi-user.target symlink." >&2
  fail=1
fi

for expected_prebuild_setting in \
  'MACBOOK_ROUNDED_CORNERS_FORCE=1' \
  'OrchardDark.colors' \
  'OrchardLight.colors' \
  '"$LIB_DIR/setup-plasma"' \
  'Orchard live environment prebuilt.'; do
  grep -qF "$expected_prebuild_setting" "$PREBUILD_LIVE" || {
    echo "Live-environment prebuild is incomplete: $expected_prebuild_setting" >&2
    fail=1
  }
done

ORCHARD_DARK_DEFAULTS="$ARCHISO/airootfs/usr/share/plasma/look-and-feel/org.orchard.dark.desktop/contents/defaults"
for expected_dark_default in \
  'ColorScheme=OrchardDark' \
  'name=default' \
  'theme=__aurorae__svg__OrchardTrafficLights'; do
  grep -qxF "$expected_dark_default" "$ORCHARD_DARK_DEFAULTS" || {
    echo "Orchard Dark global theme is missing: $expected_dark_default" >&2
    fail=1
  }
done

LIVE_WELCOME="$ARCHISO/airootfs/usr/lib/macbook-cachyos/live-welcome"
for expected_welcome_setting in \
  '/run/archiso' \
  'Install Orchard Linux.desktop' \
  'Install now' \
  'Try Orchard first'; do
  grep -qF "$expected_welcome_setting" "$LIVE_WELCOME" || {
    echo "Live installer welcome is incomplete: $expected_welcome_setting" >&2
    fail=1
  }
done

for expected_prebuild_hook_line in \
  '# remove from airootfs!' \
  'Operation = Install' \
  'Target = kwin' \
  'Target = kwin-x11' \
  'Exec = /usr/bin/bash /usr/lib/macbook-cachyos/prebuild-live-environment'; do
  grep -qxF "$expected_prebuild_hook_line" "$PREBUILD_HOOK" || {
    echo "Build-only live-environment hook is incomplete: $expected_prebuild_hook_line" >&2
    fail=1
  }
done

for expected_hook_line in \
  'Target = kwin' \
  'Target = kwin-x11' \
  'Exec = /usr/lib/macbook-cachyos/build-rounded-corners'; do
  grep -qxF "$expected_hook_line" "$ROUNDED_HOOK" || {
    echo "Rounded-corner pacman hook is incomplete: $expected_hook_line" >&2
    fail=1
  }
done

for copied_file in \
  /etc/systemd/system/macbook-background-setup.service \
  /etc/systemd/system/macbook-firstboot.service \
  /etc/systemd/system/macbook-wifi-driver.service \
  /etc/environment.d/90-orchard-input.conf \
  /usr/lib/macbook-cachyos/90-no-suspend.conf \
  /usr/lib/macbook-cachyos/70-bcm5974-libinput.conf \
  /usr/lib/macbook-cachyos/background-setup \
  /usr/lib/macbook-cachyos/build-rounded-corners \
  /usr/lib/macbook-cachyos/firstboot \
  /usr/lib/macbook-cachyos/hid-apple.conf \
  /usr/lib/macbook-cachyos/keyd-macos.conf \
  /usr/lib/macbook-cachyos/wifi-driver-setup \
  /usr/lib/qt6/plugins/kwin/effects/plugins/kwin4_effect_shapecorners.so \
  /usr/lib/qt6/plugins/kwin-x11/effects/plugins/kwin4_effect_shapecorners.so \
  /usr/local/bin/orchard-theme \
  /usr/local/bin/macbook-diagnostic-bundle \
  /usr/local/bin/orchard-trackpad \
  /etc/xdg/autostart/org.orchard.TrackpadApply.desktop \
  /usr/share/applications/org.orchard.Trackpad.desktop \
  /usr/share/applications/org.orchard.Downloads.desktop \
  /usr/share/color-schemes/OrchardDark.colors \
  /usr/share/color-schemes/OrchardLight.colors \
  /usr/share/plasma/look-and-feel/org.orchard.desktop/metadata.json \
  /usr/share/plasma/look-and-feel/org.orchard.desktop/contents/defaults \
  /usr/share/plasma/look-and-feel/org.orchard.dark.desktop/metadata.json \
  /usr/share/plasma/look-and-feel/org.orchard.dark.desktop/contents/defaults \
  /usr/share/plasma/look-and-feel/org.orchard.dark.desktop/contents/splash/Splash.qml \
  /usr/share/wallpapers/macbook-cachyos/orchard-dusk.svg \
  /var/lib/macbook-cachyos/rounded-corners-build; do
  grep -qF "\"$copied_file\"" "$CALAMARES_PATCH" || {
    echo "Installed-system overlay file not copied by Calamares patch: $copied_file" >&2
    fail=1
  }
done

if grep -q '^  - "/etc/skel/' "$CALAMARES_PATCH"; then
  echo "Calamares patch copies /etc/skel before cachyos-kde-settings is installed." >&2
  fail=1
fi

if ! grep -qE '^[[:space:]]+- name: "macbook-firstboot\.service"$' \
  "$CALAMARES_PATCH"; then
  echo "Calamares patch does not enable macbook-firstboot.service." >&2
  fail=1
fi
if ! grep -qE '^[[:space:]]+- name: "macbook-background-setup\.service"$' \
  "$CALAMARES_PATCH"; then
  echo "Calamares patch does not enable macbook-background-setup.service." >&2
  fail=1
fi
if ! grep -qE '^[[:space:]]+- name: "macbook-wifi-driver\.service"$' \
  "$CALAMARES_PATCH"; then
  echo "Calamares patch does not enable macbook-wifi-driver.service." >&2
  fail=1
fi

WIFI_SERVICE="$ARCHISO/airootfs/etc/systemd/system/macbook-wifi-driver.service"
for expected_wifi_unit_line in \
  'Before=iwd.service NetworkManager.service' \
  'ExecStart=/usr/lib/macbook-cachyos/wifi-driver-setup'; do
  grep -qxF "$expected_wifi_unit_line" "$WIFI_SERVICE" || {
    echo "MacBook Wi-Fi service is missing: $expected_wifi_unit_line" >&2
    fail=1
  }
done

if ! grep -qxF 'TimeoutStartSec=60s' \
  "$ARCHISO/airootfs/etc/systemd/system/macbook-firstboot.service"; then
  echo "MacBook first-boot service lacks its boot-progress timeout." >&2
  fail=1
fi

if ! PKGLIST="$(find_profile_package_list "$ARCHISO" "$PROFILE")"; then
  echo "Unable to validate package list." >&2
  fail=1
else
  for pkg in \
    appmenu-gtk-module \
    base-devel \
    broadcom-wl-dkms \
    cmake \
    dkms \
    extra-cmake-modules \
    flatpak \
    networkmanager \
    intel-ucode \
    ffmpegthumbs \
    kdegraphics-thumbnailers \
    keyd \
    kdialog \
    kimageformats \
    kio-extras \
    power-profiles-daemon \
    papirus-icon-theme \
    plasma-browser-integration \
    plasma-x11-session \
    qt6-imageformats \
    sddm \
    shelly \
    ninja \
    vulkan-headers \
    xorg-xinput; do
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

if [[ ! -f "$PROFILEDEF" ]] || [[ ! -f "$UTIL_ISO" ]] || [[ ! -f "$BUILDISO" ]]; then
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

if [[ -f "$BUILDISO" ]] && [[ "$(grep -cF \
  '# orchard-linux: removed unconditional EXIT error trap' "$BUILDISO")" -ne 1 ]]; then
  echo "CachyOS build entry point retains its unconditional EXIT error trap." >&2
  fail=1
fi

if [[ $fail -ne 0 ]]; then
  echo "Validation failed." >&2
  exit 1
fi

echo "Validation passed."
