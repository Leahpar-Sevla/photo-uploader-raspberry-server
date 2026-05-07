# Step 03 — Raspberry diagnostics

Script:

```text
/opt/photo-uploader/bin/diagnostic.sh
```

Checks:

```text
OS
folders
permissions
disk space
memory
temperature
USB
gphoto2
SSH
Tailscale
project scripts
```

Useful commands:

```bash
lsusb
gphoto2 --auto-detect
gphoto2 --list-files
systemctl status ssh --no-pager
tailscale status
```
