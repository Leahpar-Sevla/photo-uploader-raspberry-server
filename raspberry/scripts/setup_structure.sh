#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="/etc/photo-uploader"
CONFIG_FILE="${CONFIG_DIR}/config.env"

APP_DIR="/opt/photo-uploader"
BIN_DIR="${APP_DIR}/bin"

DEFAULT_CAM_ID="CAM-01"
DEFAULT_LOCAL_BASE="/var/photo-spool"

CURRENT_USER="${SUDO_USER:-$(whoami)}"

echo "============================================================"
echo " Photo Uploader - Setup Structure"
echo "============================================================"
echo "[INFO] User detected: ${CURRENT_USER}"

sudo mkdir -p "$APP_DIR" "$BIN_DIR" "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[INFO] Creating initial config: $CONFIG_FILE"

  sudo tee "$CONFIG_FILE" >/dev/null <<EOF
CAM_ID="${DEFAULT_CAM_ID}"
LOCAL_BASE="${DEFAULT_LOCAL_BASE}"

# Legacy/reserved fields.
# The server pulls files from the Raspberry in the current architecture.
REMOTE_USER="uploader"
REMOTE_HOST=""
REMOTE_BASE="/srv/fotos"
SSH_KEY="/home/${CURRENT_USER}/.ssh/photo_uploader_cam01"
EOF
else
  echo "[INFO] Config already exists. It will not be overwritten: $CONFIG_FILE"
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

CAM_ID="${CAM_ID:-$DEFAULT_CAM_ID}"
LOCAL_BASE="${LOCAL_BASE:-$DEFAULT_LOCAL_BASE}"
BASE_CAM="${LOCAL_BASE}/${CAM_ID}"

sudo mkdir -p "$BASE_CAM/importando"
sudo mkdir -p "$BASE_CAM/pendentes"
sudo mkdir -p "$BASE_CAM/enviados"
sudo mkdir -p "$BASE_CAM/erro"
sudo mkdir -p "$BASE_CAM/logs"
sudo mkdir -p "$BASE_CAM/controle"

sudo touch "$BASE_CAM/importando/.keep"
sudo touch "$BASE_CAM/pendentes/.keep"
sudo touch "$BASE_CAM/enviados/.keep"
sudo touch "$BASE_CAM/erro/.keep"
sudo touch "$BASE_CAM/logs/.keep"
sudo touch "$BASE_CAM/controle/.keep"

sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "$APP_DIR"
sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "$LOCAL_BASE"

sudo chown root:root "$CONFIG_DIR" "$CONFIG_FILE"
sudo chmod 755 "$CONFIG_DIR"
sudo chmod 644 "$CONFIG_FILE"

echo "[OK] Base structure created/checked."
find "$BASE_CAM" -maxdepth 2 -type d | sort
