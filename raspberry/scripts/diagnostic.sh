#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/photo-uploader/config.env"

section() {
  echo
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

has_command() { command -v "$1" >/dev/null 2>&1; }

check_cmd() {
  if has_command "$1"; then
    echo "[OK] $1 -> $(command -v "$1")"
  else
    echo "[FALHA] comando ausente: $1"
  fi
}

check_dir() {
  if [ -d "$1" ]; then
    echo "[OK] diretório existe: $1"
  else
    echo "[FALHA] diretório ausente: $1"
  fi
}

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[FALHA] Config não encontrado: $CONFIG_FILE"
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
LOG_FILE="${LOG_DIR}/diagnostic_${CAM_ID}_${TS}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo " Photo Uploader - Diagnóstico do Raspberry"
echo "============================================================"
echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Hostname: $(hostname)"
echo "Usuário: $(whoami)"
echo "CAM_ID: $CAM_ID"
echo "BASE_CAM: $BASE_CAM"
echo "Log: $LOG_FILE"
echo "============================================================"

section "1. Sistema"
uname -a
cat /etc/os-release 2>/dev/null || true

section "2. Configuração"
cat "$CONFIG_FILE"

section "3. Estrutura"
check_dir /opt/photo-uploader
check_dir /opt/photo-uploader/bin
check_dir /etc/photo-uploader
check_dir "$BASE_CAM"
check_dir "$BASE_CAM/importando"
check_dir "$BASE_CAM/pendentes"
check_dir "$BASE_CAM/enviados"
check_dir "$BASE_CAM/erro"
check_dir "$BASE_CAM/logs"
check_dir "$BASE_CAM/controle"

section "4. Permissões"
ls -ld /opt/photo-uploader /opt/photo-uploader/bin /etc/photo-uploader "$LOCAL_BASE" "$BASE_CAM"
ls -ld "$BASE_CAM"/*

section "5. Disco e memória"
df -h /
df -h "$LOCAL_BASE"
free -h

section "6. Temperatura e energia"
if has_command vcgencmd; then
  vcgencmd measure_temp || true
  vcgencmd get_throttled || true
else
  echo "[AVISO] vcgencmd ausente"
fi

section "7. Comandos necessários"
for cmd in bash find grep flock gphoto2 lsusb rsync ssh curl; do
  check_cmd "$cmd"
done

section "8. Rede e SSH"
hostname -I || true
ip route || true
systemctl is-active ssh || true
systemctl status ssh --no-pager -l || true

section "9. Tailscale"
if has_command tailscale; then
  tailscale status || true
  tailscale ip -4 || true
else
  echo "[AVISO] Tailscale não instalado"
fi

section "10. USB e câmera"
lsusb || true
gphoto2 --auto-detect || true

section "11. Eventos USB recentes"
sudo dmesg | grep -Ei "usb|gphoto|ptp|mtp|canon|error|fail|reset|descriptor|undervoltage" | tail -80 || true

section "12. Scripts do projeto"
ls -lah /opt/photo-uploader/bin
for script in setup_structure.sh import_from_camera.sh import_from_camera_incremental.sh diagnostic.sh cleanup_sent.sh; do
  if [ -x "/opt/photo-uploader/bin/$script" ]; then
    echo "[OK] $script executável"
  else
    echo "[AVISO] $script ausente ou sem execução"
  fi
done

section "13. Sessões locais"
echo "Pendentes:"
find "$BASE_CAM/pendentes" -maxdepth 2 -name ".READY" -type f | sort || true
echo
echo "Importando:"
find "$BASE_CAM/importando" -maxdepth 2 -type f | sort || true
echo
echo "Enviados:"
find "$BASE_CAM/enviados" -maxdepth 2 -name ".READY" -type f | sort || true
echo
echo "Erro:"
find "$BASE_CAM/erro" -maxdepth 2 -type f | sort || true

echo
echo "============================================================"
echo "Diagnóstico finalizado."
echo "Log salvo em:"
echo "$LOG_FILE"
echo "============================================================"
