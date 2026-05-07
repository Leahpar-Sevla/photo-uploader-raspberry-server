# Architecture

## Current design

```text
Camera
↓
Raspberry Pi
↓
/var/photo-spool/CAM-XX/pendentes/
↓
Linux server pulls with SSH/rsync
↓
EXTERNAS/CAM-XX/
↓
Samba/backup
```

## Why server pull?

The server is usually more stable and better suited for:

```text
storage
backup
Samba sharing
central logs
multi-device orchestration
```

The Raspberry remains focused on:

```text
camera import
local queue
temporary backup
cleanup of sent sessions
```

## Rules

```text
PDV/Windows clients never access the Raspberry directly.
The server only pulls .READY sessions.
The server copies to .tmp first.
The server moves remote sessions to enviados/ after success.
The Raspberry only cleans enviados/.
```
