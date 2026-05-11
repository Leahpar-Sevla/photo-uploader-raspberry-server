#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/photo-uploader/config.env"

source "$CONFIG_FILE"

CAM_ID="${CAM_ID:-CAM-01}"
LOCAL_BASE="${LOCAL_BASE:-/var/photo-spool}"
BASE_CAM="${LOCAL_BASE}/${CAM_ID}"

LOG_DIR="${BASE_CAM}/logs"
CONTROL_DIR="${BASE_CAM}/controle"

mkdir -p "$LOG_DIR" "$CONTROL_DIR"

LOG_FILE="${LOG_DIR}/camera_hotplug_$(date '+%Y-%m-%d').log"
LOCK_FILE="${CONTROL_DIR}/camera_hotplug.lock"

CAMERA_USB_ID="04a9:3294"

now() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(now)] [INFO] $*"
}

warn() {
  echo "[$(now)] [AVISO] $*"
}

camera_seen_usb() {
  lsusb | grep -qi "$CAMERA_USB_ID"
}

exec 9>"$LOCK_FILE"

if ! flock -n 9; then
  exit 0
fi

exec > >(tee -a "$LOG_FILE") 2>&1

if ! camera_seen_usb; then
  log "Câmera não vista no USB. Nada a fazer."
  exit 0
fi

log "============================================================"
log "Câmera vista no USB - verificando importação incremental"
log "CAM_ID: $CAM_ID"
log "Log: $LOG_FILE"
log "============================================================"

log "Aguardando estabilização rápida da câmera..."
sleep 2

log "Limpando possíveis monitores GVFS que seguram PTP..."
pkill -f gvfs-gphoto2-volume-monitor || true
pkill -f gvfsd-gphoto2 || true

log "Verificando câmera com gphoto2..."
CAMERA_READY=0

for attempt in 1 2 3 4 5 6 7 8; do
  if gphoto2 --auto-detect | awk 'NR>2 {found=1} END {exit found ? 0 : 1}'; then
    CAMERA_READY=1
    log "Câmera detectada na tentativa ${attempt}."
    break
  fi

  warn "Câmera ainda não pronta. Tentativa ${attempt}/8."
  sleep 1
done

if [ "$CAMERA_READY" != "1" ]; then
  warn "Câmera apareceu no USB, mas não ficou pronta no gphoto2. Saindo."
  exit 0
fi

log "Rodando verificação/importação incremental."
log "A sessão só será criada se houver arquivo novo."

if /opt/photo-uploader/bin/import_from_camera_incremental.sh; then
  log "Verificação/importação incremental finalizada."
  log "============================================================"
else
  warn "Importação incremental retornou erro."
  exit 1
fi
