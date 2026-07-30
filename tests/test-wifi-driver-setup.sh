#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/overlay/airootfs/usr/lib/macbook-cachyos/wifi-driver-setup"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -r -- "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_ROOT/dmi"
CALLS="$TEST_ROOT/modprobe-calls"
PCI_FIXTURE="$TEST_ROOT/pci"

cat > "$TEST_ROOT/lspci" <<EOF
#!/usr/bin/env bash
cat "$PCI_FIXTURE"
EOF
cat > "$TEST_ROOT/modprobe" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$CALLS"
EOF
chmod 0755 "$TEST_ROOT/lspci" "$TEST_ROOT/modprobe"

run_setup() {
  : > "$CALLS"
  ORCHARD_DMI_ROOT="$TEST_ROOT/dmi" \
    ORCHARD_LSPCI_BIN="$TEST_ROOT/lspci" \
    ORCHARD_MODPROBE_BIN="$TEST_ROOT/modprobe" \
    "$SCRIPT"
}

printf '%s\n' 'Apple Inc.' > "$TEST_ROOT/dmi/sys_vendor"
printf '%s\n' 'MacBookPro12,1' > "$TEST_ROOT/dmi/product_name"
printf '%s\n' \
  '0000:03:00.0 0280: 14e4:43ba (rev 01)' \
  > "$PCI_FIXTURE"
run_setup
cat > "$TEST_ROOT/expected" <<'EOF'
-r brcmfmac_wcc
-r brcmfmac
-r wl
brcmfmac feature_disable=0x82000
EOF
cmp "$TEST_ROOT/expected" "$CALLS"

printf '%s\n' \
  '0000:03:00.0 0280: 14e4:4331 (rev 02)' \
  > "$PCI_FIXTURE"
run_setup
printf '%s\n' 'wl' > "$TEST_ROOT/expected"
cmp "$TEST_ROOT/expected" "$CALLS"

printf '%s\n' 'Example Vendor' > "$TEST_ROOT/dmi/sys_vendor"
run_setup
[[ ! -s "$CALLS" ]]

echo "Wi-Fi driver setup tests passed."
