# MacBook CachyOS Edition

A reproducible overlay for the official CachyOS Live ISO project, aimed at Intel
MacBook Pro hardware from roughly 2012–2014.

This is a **starter build kit**, not a separately maintained Linux distribution.
It keeps CachyOS upstream as the source of the ISO and applies a small,
reviewable overlay.

## Goals

- Broadcom Wi-Fi available in the live environment
- Broadcom support explicitly installed in the target system through the
  upstream Calamares pacstrap flow
- Intel microcode, NetworkManager, Bluetooth, thermald, fwupd,
  power-profiles-daemon and useful diagnostic tools
- A first-boot hardware detection service for Intel Macs
- KDE Plasma defaults arranged in a macOS-like layout
- No Apple fonts, Apple artwork, or copied MX Linux binaries
- No bundled AUR packages

## Important limitations

1. The build must be run from an up-to-date Arch Linux or CachyOS x86_64 system.
2. CachyOS changes its ISO and Calamares layouts over time. The overlay script
   searches for common package-list locations and stops rather than silently
   modifying the wrong file.
3. `broadcom-wl-dkms` needs matching kernel headers. The script detects every
   kernel in the selected ISO profile, excludes companion module packages, and
   adds the corresponding `-headers` packages.
4. The Broadcom `wl` driver supports the common BCM4331/BCM4352/BCM4360 family,
   but not every Broadcom chip ever used by Apple.
5. Test the ISO from USB before installing. Keep Ethernet or USB phone tethering
   available during initial testing.
6. KDE's internal configuration formats can change. The included Plasma setup
   is conservative and uses supported scripting where practical.


## Using this project with Codex

1. Create a GitHub repository and upload this project.
2. In ChatGPT/Codex, connect GitHub and select that repository.
3. Ask Codex to read `AGENTS.md` and begin with the near-term tasks.
4. Run the **Build MacBook CachyOS ISO** workflow from the Actions tab.
5. Download the `macbook-cachyos-iso` workflow artifact on your M2 Mac.
6. Write the ISO to USB with Balena Etcher or Raspberry Pi Imager.

The workflow builds on GitHub's x86_64 Linux runner, so the M2 Mac only needs to
download the completed ISO and write it to the USB drive.

## Build

```bash
git clone https://github.com/CachyOS/CachyOS-Live-ISO.git
git clone <this-project-or-extract-the-zip> macbook-cachyos-edition
cd macbook-cachyos-edition

sudo ./build.sh \
  --upstream ../CachyOS-Live-ISO \
  --name macbook-cachyos
```

The resulting ISO should appear in the upstream project's `out/desktop/`
directory.

To let the script clone CachyOS automatically:

```bash
sudo ./build.sh --clone-upstream
```

## Test in a VM

Broadcom Wi-Fi and MacBook-specific hardware cannot be meaningfully verified in
a normal VM, but bootability can:

```bash
./test-vm.sh ../CachyOS-Live-ISO/out/*.iso
```

## Write to USB

Replace `/dev/sdX` with the whole USB device, not a partition:

```bash
sudo dd if=path/to/image.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

On macOS, use the raw device such as `/dev/rdisk4` after unmounting it.

## Diagnose on a MacBook

From the live environment:

```bash
sudo macbook-hardware-report
sudo macbook-diagnostic-bundle
lspci -nnk | grep -A4 -i network
lsmod | grep -E '^(wl|b43|brcm)'
journalctl -b -k | grep -Ei 'broadcom|b43|brcm|firmware|wl'
```

## Broadcom strategy

The ISO installs:

- `broadcom-wl-dkms`
- `dkms`
- matching kernel headers when detectable
- `linux-firmware`
- `wireless-regdb`
- `iwd`
- `networkmanager`

Current CachyOS Calamares installs a fresh target with `pacstrap`; it does not
simply copy the live root filesystem. The overlay therefore extends both the
live profile and Calamares's target package list. Both CachyOS kernels receive
matching headers in the target system.

The package's own modprobe configuration handles the usual conflicting modules.
The first-boot service asks modprobe to load `wl` only when a runtime PCI device
with Broadcom vendor ID `14e4` is present. The driver's PCI aliases remain
authoritative, and the service does not forcibly unload alternative drivers.

We intentionally do **not** bundle `b43-firmware` from the AUR. That package has
had source availability and maintenance problems, and the target MacBook models
are better served by the packaged Broadcom STA driver in most cases.

`mbpfan` is also currently available only from the AUR, so it is not bundled.
The image uses upstream's `power-profiles-daemon` and does not install or enable
TLP at the same time. Fan behavior remains a hardware-test item until an
officially packaged, reproducible option is selected.

## macOS-like Plasma appearance

The included setup provides:

- top panel
- application menu at top-left
- clock and system tray at top-right
- floating bottom task manager/dock
- KRunner shortcut on `Meta+Space`
- single-click disabled
- natural scrolling enabled where libinput supports it
- four virtual desktops
- dark/light colour-scheme hook points

It does not redistribute WhiteSur, Apple icons, San Francisco fonts, or Apple
wallpapers. Those assets have separate licensing and update concerns. A helper
is included for installing optional third-party themes after the system is
online.

## Project layout

```text
overlay/
  airootfs/
    etc/
    usr/
scripts/
  apply-overlay.sh
  patch-package-list.sh
  validate.sh
build.sh
test-vm.sh
```

## Suggested hardware test matrix

- MacBookPro9,1 and 9,2 (2012 non-Retina)
- MacBookPro10,1 and 10,2 (2012 Retina)
- MacBookPro11,1, 11,2 and 11,3 (2013–2014 Retina)

Record:

- Wi-Fi chip PCI ID
- live Wi-Fi before installation
- installed Wi-Fi after reboot
- suspend/resume
- brightness keys
- keyboard backlight
- trackpad tap, scroll and gestures
- audio
- webcam
- thermals and fan behaviour

See [docs/UPSTREAM-COMPATIBILITY.md](docs/UPSTREAM-COMPATIBILITY.md) for the
verified upstream layout and package decisions. Use
[docs/HARDWARE-TEST.md](docs/HARDWARE-TEST.md) for model test reports.

## License

Project scripts: GPL-3.0-or-later.

CachyOS, Arch Linux, Broadcom, Apple and macOS names and marks belong to their
respective owners. This project is not affiliated with them.
