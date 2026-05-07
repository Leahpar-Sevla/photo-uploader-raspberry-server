# Example laboratory flow

This file uses fake data.

```text
Raspberry:
CAM_ID=CAM-01
HOST=100.xxx.xxx.xxx
USER=photo-sync
REMOTE_BASE=/var/photo-spool/CAM-01

Server:
DEST_BASE=/srv/server/EXTERNAS
SSH_KEY=/home/photo-sync/.ssh/rasp_cam01
```

Create fake session on Raspberry:

```bash
SESSION="CAM-01_2026-05-07_153000"
BASE="/var/photo-spool/CAM-01/pendentes/$SESSION"

mkdir -p "$BASE"
echo "test image 1" > "$BASE/photo_001.jpg"
echo "test image 2" > "$BASE/photo_002.jpg"
echo "SESSION=$SESSION" > "$BASE/manifest.txt"
touch "$BASE/.READY"
```

Run on server:

```bash
/opt/photo-server/bin/pull_externas.sh
```

Expected result:

```text
EXTERNAS/CAM-01/CAM-01_2026-05-07_153000/
├── photo_001.jpg
├── photo_002.jpg
├── manifest.txt
├── .READY
└── .PULLED_BY_SERVER
```
