# Photo Uploader Raspberry + Linux Server

![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Photo%20Uploader-C51A4A)
![Linux Server](https://img.shields.io/badge/Linux%20Server-SSH%2Frsync-0078D6)
![License](https://img.shields.io/badge/License-MIT-blue)


Reference project for importing photos from cameras connected to Raspberry Pi devices and centralizing them on an existing Linux server.

The architecture is intentionally simple and operational:

```text
Camera
↓
Raspberry Pi imports photos
↓
Raspberry creates a session in pendentes/ with .READY
↓
Linux server pulls ready sessions via SSH/rsync
↓
Server stores files in EXTERNAS/CAM-XX/
↓
Windows/PDV clients access only the Linux server via Samba
↓
Raspberry keeps sent sessions temporarily in enviados/
↓
Raspberry periodically cleans enviados/
```

## Core rule

```text
The server pulls from the Raspberry.
The Raspberry does not actively push files to the server.
```

This keeps the Raspberry lightweight and lets the server centralize storage, logs, Samba, and backup.

## Use cases

- Photo booths
- Event photo workflows
- Local retail/PDV photo operations
- Camera-to-server automation
- Raspberry Pi field collectors

## What this project includes

```text
raspberry/scripts/
├── setup_structure.sh
├── import_from_camera.sh
├── diagnostic.sh
└── cleanup_sent.sh

raspberry/systemd/
├── photo-cleanup-sent.service
└── photo-cleanup-sent.timer

server/scripts/
└── pull_externas.sh

server/systemd/
├── photo-pull-externas.service
└── photo-pull-externas.timer

server/config/
└── rasps.conf.example
```

## Official paths

On Raspberry:

```text
/etc/photo-uploader/config.env
/opt/photo-uploader/bin/
/var/photo-spool/CAM-XX/
```

On server:

```text
/etc/photo-server/rasps.conf
/opt/photo-server/bin/pull_externas.sh
EXTERNAS/CAM-XX/
EXTERNAS/.controle/
```

Example server destination:

```text
/srv/server/EXTERNAS/
```

## Raspberry folder structure

```text
/var/photo-spool/CAM-XX/
├── importando/
├── pendentes/
├── enviados/
├── erro/
├── logs/
└── controle/
```

Folder meanings:

```text
importando/  temporary import area
pendentes/   sessions ready for server pull
enviados/    sessions already pulled by server
erro/        failed imports
logs/        local logs
controle/    lock/control files
```

## Server folder structure

```text
EXTERNAS/
├── CAM-01/
│   ├── .tmp/
│   └── CAM-01_YYYY-MM-DD_HHMMSS/
└── .controle/
    ├── baixados.log
    ├── erros.log
    ├── pull_externas.log
    └── pull.lock
```

## Session naming

Use this format:

```text
CAM-XX_YYYY-MM-DD_HHMMSS
```

Example:

```text
CAM-01_2026-05-07_153000
```

The cleanup script relies on sortable session names to keep the most recent session.

## Important markers

```text
.READY
```

Created by the Raspberry after a successful import. The server only pulls sessions with `.READY`.

```text
.PULLED_BY_SERVER
```

Created by the server after a successful pull.

```text
.keep
```

Used to keep empty folders in place.

## Quick Raspberry installation

```bash
sudo apt update
sudo apt install -y gphoto2 usbutils rsync openssh-client openssh-server curl nano htop lsof jq ca-certificates

sudo mkdir -p /opt/photo-uploader/bin
sudo mkdir -p /etc/photo-uploader

sudo cp raspberry/scripts/*.sh /opt/photo-uploader/bin/
sudo chmod +x /opt/photo-uploader/bin/*.sh

sudo cp raspberry/config/config.env.example /etc/photo-uploader/config.env
sudo nano /etc/photo-uploader/config.env

sudo /opt/photo-uploader/bin/setup_structure.sh
/opt/photo-uploader/bin/diagnostic.sh
```

Install Raspberry cleanup timer:

```bash
sudo cp raspberry/systemd/photo-cleanup-sent.service /etc/systemd/system/
sudo cp raspberry/systemd/photo-cleanup-sent.timer /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now photo-cleanup-sent.timer
```

## Quick server installation

Confirm the real `EXTERNAS` path before installing.

```bash
sudo apt update
sudo apt install -y rsync openssh-client tailscale nano htop curl ca-certificates

sudo mkdir -p /opt/photo-server/bin
sudo mkdir -p /etc/photo-server
sudo mkdir -p /srv/server/EXTERNAS/.controle

sudo cp server/scripts/pull_externas.sh /opt/photo-server/bin/
sudo chmod +x /opt/photo-server/bin/pull_externas.sh

sudo cp server/config/rasps.conf.example /etc/photo-server/rasps.conf
sudo nano /etc/photo-server/rasps.conf
```

If your destination is not `/srv/server/EXTERNAS`, edit `DEST_BASE` in:

```bash
sudo nano /opt/photo-server/bin/pull_externas.sh
```

Install server timer:

```bash
sudo cp server/systemd/photo-pull-externas.service /etc/systemd/system/
sudo cp server/systemd/photo-pull-externas.timer /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now photo-pull-externas.timer
```

## Add a Raspberry to the server

Create SSH key on server:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/rasp_cam01 -C "server-to-rasp-cam01"
ssh-copy-id -i ~/.ssh/rasp_cam01.pub photo-sync@100.xxx.xxx.xxx
```

Add to:

```text
/etc/photo-server/rasps.conf
```

Example:

```text
CAM-01|photo-sync|100.xxx.xxx.xxx|/var/photo-spool/CAM-01|/home/photo-sync/.ssh/rasp_cam01
```

## Logs

Server:

```bash
tail -100 /srv/server/EXTERNAS/.controle/pull_externas.log
cat /srv/server/EXTERNAS/.controle/baixados.log
tail -100 /srv/server/EXTERNAS/.controle/erros.log
journalctl -u photo-pull-externas.service -n 100 --no-pager
```

Raspberry:

```bash
tail -100 /var/photo-spool/CAM-01/logs/cleanup_sent_$(date '+%Y-%m-%d').log
journalctl -u photo-cleanup-sent.service -n 100 --no-pager
```

## Security notes

Do not commit:

```text
real Tailscale IPs
private SSH keys
real public keys
real logs
real client/server names
credentials
tokens
backups
```

Use `.example` files and placeholders.

## Project status

This is a portfolio/reference model. Test and adapt before production use.
