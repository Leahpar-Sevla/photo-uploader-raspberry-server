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
echo "[INFO] Usuário de manutenção detectado: ${CURRENT_USER}"

sudo mkdir -p "$APP_DIR" "$BIN_DIR" "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[INFO] Criando configuração inicial: $CONFIG_FILE"
  sudo tee "$CONFIG_FILE" >/dev/null <<CONFIGEOF
CAM_ID="${DEFAULT_CAM_ID}"
LOCAL_BASE="${DEFAULT_LOCAL_BASE}"

# Campos reservados/legados.
# No fluxo atual, o servidor busca as fotos no Raspberry.
REMOTE_USER="uploader"
REMOTE_HOST=""
REMOTE_BASE="/srv/fotos"
SSH_KEY="/home/${CURRENT_USER}/.ssh/photo_uploader_cam01"
CONFIGEOF
else
  echo "[INFO] Configuração já existe. Não será sobrescrita: $CONFIG_FILE"
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

CAM_ID="${CAM_ID:-$DEFAULT_CAM_ID}"
LOCAL_BASE="${LOCAL_BASE:-$DEFAULT_LOCAL_BASE}"
BASE_CAM="${LOCAL_BASE}/${CAM_ID}"

echo "[INFO] CAM_ID: $CAM_ID"
echo "[INFO] LOCAL_BASE: $LOCAL_BASE"
echo "[INFO] BASE_CAM: $BASE_CAM"

sudo mkdir -p "$BASE_CAM/importando" "$BASE_CAM/pendentes" "$BASE_CAM/enviados" "$BASE_CAM/erro" "$BASE_CAM/logs" "$BASE_CAM/controle"

sudo touch "$BASE_CAM/importando/.keep" "$BASE_CAM/pendentes/.keep" "$BASE_CAM/enviados/.keep" "$BASE_CAM/erro/.keep" "$BASE_CAM/logs/.keep" "$BASE_CAM/controle/.keep"

sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "$APP_DIR"
sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "$LOCAL_BASE"
sudo chown root:root "$CONFIG_DIR" "$CONFIG_FILE"
sudo chmod 755 "$CONFIG_DIR"
sudo chmod 644 "$CONFIG_FILE"

echo
echo "[OK] Estrutura base criada/conferida."
find "$BASE_CAM" -maxdepth 2 -type d | sort
echo
cat "$CONFIG_FILE"
