# Target model notes

The exact wireless card can vary by MacBook configuration and repair history.
Always trust the PCI ID reported by `lspci -nn`, not the marketing model alone.

Common target families:

| Apple model | Approximate generation | Likely Wi-Fi family |
|---|---:|---|
| MacBookPro9,1 / 9,2 | 2012 non-Retina | BCM4331-class |
| MacBookPro10,1 / 10,2 | 2012 Retina | BCM4331-class |
| MacBookPro11,1 | Late 2013 / Mid 2014 13-inch Retina | BCM4360-class |
| MacBookPro11,2 / 11,3 | Late 2013 / Mid 2014 15-inch Retina | BCM4360-class |

These are guidelines, not guarantees.

## Recorded hardware tests

- [MacBookPro10,1 — 2026-07-28](hardware-tests/MacBookPro10,1-2026-07-28.md):
  BCM4331 `14e4:4331` with Apple subsystem `106b:00ef`; live Wi-Fi connected
  successfully using `wl`.

Useful commands:

```bash
cat /sys/class/dmi/id/product_name
lspci -nnk
sudo macbook-hardware-report
```

Known areas requiring model-by-model testing:

- Broadcom Wi-Fi stability after suspend
- dual-GPU MacBookPro11,3 graphics selection
- FaceTime HD camera firmware
- Thunderbolt
- trackpad gesture richness
- fan curves
- battery condition
