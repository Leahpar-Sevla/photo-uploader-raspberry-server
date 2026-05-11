#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/photo-uploader/config.env"

now() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(now)] [INFO] $*"; }
warn() { echo "[$(now)] [AVISO] $*"; }
error() { echo "[$(now)] [ERRO] $*"; }

fail_session() {
  local reason="$1"
  error "$reason"

  if [ -n "${SESSION_DIR_TMP:-}" ] && [ -d "$SESSION_DIR_TMP" ]; then
    mkdir -p "$ERROR_DIR"
    local error_target="${ERROR_DIR}/${SESSION}_FALHA_$(date '+%H%M%S')"
    warn "Movendo sessão com falha para: $error_target"
    mv "$SESSION_DIR_TMP" "$error_target" || true
  fi

  exit 1
}

load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERRO] Arquivo de configuração não encontrado: $CONFIG_FILE"
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  CAM_ID="${CAM_ID:-CAM-01}"
  LOCAL_BASE="${LOCAL_BASE:-/var/photo-spool}"

  BASE_CAM="${LOCAL_BASE}/${CAM_ID}"

  IMPORTING_DIR="${BASE_CAM}/importando"
  PENDING_DIR="${BASE_CAM}/pendentes"
  SENT_DIR="${BASE_CAM}/enviados"
  ERROR_DIR="${BASE_CAM}/erro"
  LOG_DIR="${BASE_CAM}/logs"
  CONTROL_DIR="${BASE_CAM}/controle"

  mkdir -p "$IMPORTING_DIR" "$PENDING_DIR" "$SENT_DIR" "$ERROR_DIR" "$LOG_DIR" "$CONTROL_DIR"

  LOCK_FILE="${CONTROL_DIR}/import.lock"
}

create_session() {
  TS="$(date '+%Y-%m-%d_%H%M%S')"
  SESSION="${CAM_ID}_${TS}"

  SESSION_DIR_TMP="${IMPORTING_DIR}/${SESSION}"
  SESSION_DIR_FINAL="${PENDING_DIR}/${SESSION}"
  LOG_FILE="${LOG_DIR}/import_${SESSION}.log"

  mkdir -p "$SESSION_DIR_TMP"
}

check_commands() {
  command -v gphoto2 >/dev/null 2>&1 || {
    echo "[ERRO] gphoto2 não encontrado."
    exit 1
  }

  command -v flock >/dev/null 2>&1 || {
    echo "[ERRO] flock não encontrado."
    exit 1
  }
}

detect_camera() {
  log "Verificando câmera conectada..."

  if ! gphoto2 --auto-detect | awk 'NR>2 {found=1} END {exit found ? 0 : 1}'; then
    warn "Nenhuma câmera detectada pelo gphoto2."
    warn "Conecte a câmera, ligue-a e tente novamente."
    if [ -n "${SESSION_DIR_TMP:-}" ] && [ -d "$SESSION_DIR_TMP" ]; then
      rmdir "$SESSION_DIR_TMP" 2>/dev/null || true
    fi
    exit 0
  fi

  log "Câmera detectada."
}

import_files() {
  log "Iniciando cópia dos arquivos para: $SESSION_DIR_TMP"

  pushd "$SESSION_DIR_TMP" >/dev/null

  if ! gphoto2 --get-all-files --filename "%03n_%f.%C"; then
    popd >/dev/null || true
    fail_session "Falha durante cópia da câmera via gphoto2."
  fi

  popd >/dev/null

  FILE_COUNT="$(find "$SESSION_DIR_TMP" -type f | wc -l | tr -d ' ')"

  log "Arquivos importados inicialmente: $FILE_COUNT"

  if [ "$FILE_COUNT" -lt 1 ]; then
    fail_session "Nenhum arquivo foi copiado da câmera."
  fi
}

create_manifest() {
  local manifest="${SESSION_DIR_TMP}/manifest.txt"

  log "Criando manifest.txt"

  {
    echo "SESSION=${SESSION}"
    echo "CAM_ID=${CAM_ID}"
    echo "IMPORT_DATE=$(now)"
    echo "HOSTNAME=$(hostname)"
    echo "SOURCE=gphoto2"
    echo "MODE=full"
    echo
    echo "FILES:"
    find "$SESSION_DIR_TMP" \
      -maxdepth 1 \
      -type f \
      ! -name "manifest.txt" \
      ! -name ".READY" \
      -printf '%f\n' \
      | sort \
      | while read -r file; do
          size="$(stat -c '%s' "${SESSION_DIR_TMP}/${file}" 2>/dev/null || echo 0)"
          echo "${file} | ${size} bytes"
        done
  } > "$manifest"
}

mark_ready() {
  log "Criando marcador .READY"
  touch "${SESSION_DIR_TMP}/.READY"
}

move_to_pending() {
  if [ -e "$SESSION_DIR_FINAL" ]; then
    fail_session "Já existe uma sessão com o mesmo nome em pendentes/: $SESSION_DIR_FINAL"
  fi

  log "Movendo sessão para pendentes/: $SESSION_DIR_FINAL"
  mv "$SESSION_DIR_TMP" "$SESSION_DIR_FINAL"
}

main() {
  check_commands
  load_config
  create_session

  exec > >(tee -a "$LOG_FILE") 2>&1

  exec 9>"$LOCK_FILE"

  if ! flock -n 9; then
    warn "Outra importação já está em andamento. Saindo."
    exit 0
  fi

  log "============================================================"
  log "Photo Uploader - Importação da câmera"
  log "CAM_ID: $CAM_ID"
  log "Sessão: $SESSION"
  log "Base local: $BASE_CAM"
  log "Log: $LOG_FILE"
  log "============================================================"

  detect_camera
  import_files
  create_manifest
  mark_ready
  move_to_pending

  log "Importação finalizada com sucesso."
  log "Sessão pronta para o servidor buscar:"
  log "$SESSION_DIR_FINAL"
  log "============================================================"
}

main "$@"
