#!/usr/bin/env bash
set -Eeuo pipefail
ISO="${1:?usage: test-vm.sh IMAGE.iso}"
[[ -f "$ISO" ]] || { echo "ISO not found: $ISO" >&2; exit 1; }

command -v qemu-system-x86_64 >/dev/null || {
  echo "Install qemu-desktop/qemu-system-x86_64 first." >&2
  exit 1
}

qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 4 \
  -machine q35 \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -cdrom "$ISO" \
  -boot d
