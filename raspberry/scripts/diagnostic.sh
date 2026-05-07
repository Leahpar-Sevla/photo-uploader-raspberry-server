#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/photo-uploader/config.env"

has_command() { command -v "$1" >/dev/null 2>&1; }
line() { echo "------------------------------------------------------------"; }
section() { echo; line; echo "$1"; line; }

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[ERROR] Config not found: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

CAM_ID="${CAM_ID:-CAM-01}"
LOCAL_BASE="${LOCAL_BASE:-/var/photo-spool}"
BASE_CAM="${LOCAL_BASE}/${CAM_ID}"
LOG_DIR="${BASE_CAM}/logs"

mkdir -p "$LOG_DIR"

TS="$(date '+%Y-%m-%d_%H%M%S')"
LOGFILE="${LOG_DIR}/diagnostic_${CAM_ID}_${TS}.log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "============================================================"
echo " Photo Uploader - Raspberry Diagnostic"
echo "============================================================"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "CAM_ID: $CAM_ID"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Config: $CONFIG_FILE"
echo "Log: $LOGFILE"
echo "============================================================"

section "System"
uname -a
[ -f /etc/os-release ] && cat /etc/os-release

section "Config"
echo "CAM_ID=$CAM_ID"
echo "LOCAL_BASE=$LOCAL_BASE"
echo "BASE_CAM=$BASE_CAM"

section "Directories"
for d in \
  /opt/photo-uploader \
  /opt/photo-uploader/bin \
  /etc/photo-uploader \
  "$LOCAL_BASE" \
  "$BASE_CAM" \
  "$BASE_CAM/importando" \
  "$BASE_CAM/pendentes" \
  "$BASE_CAM/enviados" \
  "$BASE_CAM/erro" \
  "$BASE_CAM/logs" \
  "$BASE_CAM/controle"
do
  [ -d "$d" ] && echo "[OK] $d" || echo "[MISSING] $d"
done

section "Disk"
df -h
df -h "$LOCAL_BASE" || true

section "Memory"
free -h || true

section "Temperature and throttling"
if has_command vcgencmd; then
  vcgencmd measure_temp || true
  vcgencmd get_throttled || true
else
  echo "[WARN] vcgencmd not found"
fi

section "Commands"
for cmd in bash find grep flock gphoto2 lsusb rsync ssh curl tailscale; do
  if has_command "$cmd"; then
    echo "[OK] $cmd -> $(command -v "$cmd")"
  else
    echo "[MISSING] $cmd"
  fi
done

section "Network"
hostname -I || true
ip addr || true
ip route || true

section "SSH"
systemctl status ssh --no-pager || true

section "Tailscale"
if has_command tailscale; then
  tailscale status || true
  tailscale ip -4 || true
else
  echo "[WARN] tailscale not found"
fi

section "USB"
lsusb || true

section "gphoto2"
gphoto2 --auto-detect || true

section "Kernel USB events"
dmesg | grep -Ei "usb|gphoto|ptp|mtp|canon|error|fail|reset|descriptor" | tail -80 || true

section "Project scripts"
ls -lah /opt/photo-uploader/bin || true

echo
echo "Diagnostic completed."
echo "Log saved at: $LOGFILE"
