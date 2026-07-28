# Upstream compatibility

## Verified source

- Repository: `CachyOS/CachyOS-Live-ISO`
- Branch: `master`
- Commit: `6a8f78c178c70c5a2ec46307d71a0566fe1d27b2`
- Verified: 2026-07-28
- Supported profile: `desktop`

The build intentionally checks concrete upstream paths and stops when they are
not present. A future layout must be inspected before another path is accepted.

## Current layout and build

The editable desktop package source is:

```text
archiso/packages_desktop.x86_64
```

During `prepare_profile`, upstream copies that file to
`archiso/packages.x86_64`. Patching the generated file would be ineffective, so
this project always prefers the profile source. Legacy
`archiso/packages.x86_64` and `archiso/Packages-Desktop` layouts remain
recognized for older verified checkouts.

The current upstream build command is:

```bash
./buildiso.sh -p desktop -v -w
```

Artifacts are written below:

```text
out/desktop/
```

## Live package setup

`archiso/pacman.conf` enables the CachyOS repository before Arch `core`, `extra`,
and `multilib`. The overlay adds `broadcom-wl-dkms`, DKMS, both detected kernel
header packages, firmware, wireless tools, Intel diagnostics, thermald, fwupd,
and power-profiles-daemon.

At the verified commit, the profile includes:

```text
linux-cachyos
linux-cachyos-lts
```

The overlay consequently adds:

```text
linux-cachyos-headers
linux-cachyos-lts-headers
```

Kernel companion packages such as `*-nvidia-open`, `*-r8125`, `*-zfs`, and
`*-dbg` are explicitly excluded from kernel detection.

## Installed-system setup

The current `cachyos-calamares` package uses its online `pacstrap` module. The
installed system is not a copy of the live package set. The overlay therefore
provides a reviewed `pacstrap.conf` that:

- installs Broadcom DKMS and headers in the target;
- installs power-profiles-daemon, not TLP;
- copies the MacBook services and diagnostics into the target.

The reviewed `services-systemd.conf` enables `macbook-firstboot.service`.
The service itself requires both `Apple Inc.` firmware vendor identification
and a `MacBook*` product identifier before making hardware-specific changes.

These overrides were compared with `cachyos-calamares` version `3.4.2-4`.
Whenever CachyOS changes that package's Calamares configuration, compare and
refresh both overrides before shipping an ISO.

## Package decisions

- `broadcom-wl-dkms` is currently in Arch Extra and the CachyOS repository.
- Matching CachyOS headers are in the CachyOS repository.
- `thermald`, `fwupd`, and power-profiles-daemon are official packages.
- `mbpfan` is currently AUR-only and is deliberately not bundled.
- `b43-firmware` is not bundled from the AUR.
- TLP is not installed alongside power-profiles-daemon.

No Apple assets, MX Linux binaries, or AUR package artifacts are included.
