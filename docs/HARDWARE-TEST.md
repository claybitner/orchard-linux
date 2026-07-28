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

Run:

```bash
sudo macbook-hardware-report > macbook-report.txt
```

Attach `macbook-report.txt` to the GitHub issue.

## Result

- Ready:
- Blocking problems:
- Non-blocking problems:
- Notes:
