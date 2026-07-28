# Codex project instructions

## Mission

Build and maintain a reproducible CachyOS-based live/install ISO for Intel
MacBook hardware, initially targeting MacBook Pro models from 2012–2015.

The live USB must provide working Wi-Fi before installation wherever the
packaged Arch/CachyOS Broadcom drivers support the detected adapter.

## Priorities

1. A bootable ISO produced by GitHub Actions.
2. Broadcom Wi-Fi in both the live environment and installed system.
3. Safe hardware detection that does not alter non-Apple computers.
4. A polished KDE Plasma configuration familiar to macOS users.
5. Model-by-model test documentation and reproducible bug reports.
6. No copied binaries from MX Linux.
7. No redistribution of Apple fonts, artwork, icons or wallpapers.
8. Prefer official Arch and CachyOS packages. Explain and isolate any AUR use.

## Supported first milestone

- MacBookPro9,1
- MacBookPro9,2
- MacBookPro10,1
- MacBookPro10,2
- MacBookPro11,1
- MacBookPro11,2
- MacBookPro11,3

## Development rules

- Read the current CachyOS-Live-ISO repository before changing assumptions
  about its directory structure or build command.
- Fail clearly when upstream layout changes. Do not silently patch an
  unverified file.
- Keep shell scripts compatible with Bash and use:
  `set -Eeuo pipefail`.
- Run `bash -n` on every shell script.
- Run ShellCheck when available.
- Never hard-code a single kernel package. Detect all included kernels and add
  matching header packages for DKMS.
- Treat model-to-chip mappings as hints only. Runtime PCI IDs are authoritative.
- Broadcom vendor ID is `14e4`; retain full PCI IDs in test reports.
- Do not blacklist generic drivers globally unless required by the installed
  Broadcom package and documented.
- Keep first-boot changes idempotent.
- Do not enable both TLP and power-profiles-daemon simultaneously.
- Avoid aggressive power-saving defaults until tested on real machines.
- Preserve an escape path: users must be able to boot with standard kernel
  parameters and disable MacBook-specific services.

## GitHub Actions

The build workflow uses an x86_64 Arch Linux container or VM and uploads the
finished ISO as an artifact. It must also upload logs when a build fails.

Do not publish an ISO as a GitHub Release until:

- the workflow succeeds,
- its SHA-256 checksum is generated,
- at least one target MacBook boots the live environment,
- Wi-Fi is verified before installation,
- Wi-Fi survives installation and reboot.

## Pull request expectations

Every PR should state:

- target model(s),
- exact PCI IDs when hardware-related,
- live-environment impact,
- installed-system impact,
- tests run,
- remaining risks.

## Useful checks

```bash
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
shellcheck build.sh test-vm.sh scripts/*.sh \
  overlay/airootfs/usr/local/bin/* \
  overlay/airootfs/usr/lib/macbook-cachyos/*
```

## Near-term tasks

1. Verify the overlay against the latest CachyOS-Live-ISO structure.
2. Make the GitHub Actions build complete successfully.
3. Confirm the exact CachyOS repository/package setup needed for
   `broadcom-wl-dkms`, kernel headers and `mbpfan`.
4. Add a boot-time diagnostic bundle that can be copied to a USB drive.
5. Add a hardware test report template.
6. Test MacBookPro10,1 or MacBookPro10,2 first.
7. Only after hardware works, refine KDE appearance and gestures.
