# Hardware test report

## Machine

- Apple model identifier:
- Marketing model:
- EMC:
- CPU:
- RAM:
- GPU:
- Storage:
- Battery condition:

## Wireless

Paste:

```text
lspci -nnk | grep -A4 -Ei 'network|ethernet'
```

- Broadcom PCI ID:
- Live USB discovers networks: yes/no
- Live USB connects to WPA2: yes/no
- Live USB connects to WPA3: yes/no/not tested
- Installed system discovers networks: yes/no
- Installed system reconnects after reboot: yes/no
- Wi-Fi works after suspend/resume: yes/no

## Other hardware

- Bluetooth:
- Audio:
- Microphone:
- Webcam:
- Display brightness:
- Keyboard backlight:
- Trackpad pointer:
- Tap-to-click:
- Natural scrolling:
- Multi-touch gestures:
- Suspend:
- Resume:
- Fan control:
- External display:
- Thunderbolt:
- SD card:
- USB:

## Logs

At boot, the MacBook service creates:

```bash
/var/lib/macbook-cachyos/diagnostics.tar.gz
```

To make a fresh bundle directly on a mounted USB drive:

```bash
lsblk -f
sudo macbook-diagnostic-bundle \
  /run/media/liveuser/YOUR_USB_LABEL/macbook-diagnostics.tar.gz
```

The bundle contains full PCI IDs, USB devices, loaded modules, rfkill state,
NetworkManager state, DKMS state, the kernel command line, and current-boot
journals. Review it for information you do not want to publish, then attach it
to the GitHub issue.

If an archive is not useful, capture the short text report:

```bash
sudo macbook-hardware-report > macbook-report.txt
```

## Result

- Ready:
- Blocking problems:
- Non-blocking problems:
- Notes:

## Escape-path check

- Boots with the service disabled using
  `systemd.mask=macbook-firstboot.service`: yes/no
- Boots with normal CachyOS kernel parameters: yes/no
