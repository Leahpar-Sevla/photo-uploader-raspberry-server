#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/photo-uploader/config.env"

THRESHOLD_SESSIONS=10
KEEP_LATEST=1
DRY_RUN="${DRY_RUN:-0}"

now() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(now)] [INFO] $*"; }
warn() { echo "[$(now)] [AVISO] $*"; }
error() { echo "[$(now)] [ERRO] $*"; }

load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    error "Arquivo de configuração não encontrado: $CONFIG_FILE"
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  CAM_ID="${CAM_ID:-CAM-01}"
  LOCAL_BASE="${LOCAL_BASE:-/var/photo-spool}"

  BASE_CAM="${LOCAL_BASE}/${CAM_ID}"
  SENT_DIR="${BASE_CAM}/enviados"
  LOG_DIR="${BASE_CAM}/logs"
  CONTROL_DIR="${BASE_CAM}/controle"

  mkdir -p "$SENT_DIR" "$LOG_DIR" "$CONTROL_DIR"

  LOG_FILE="${LOG_DIR}/cleanup_sent_$(date '+%Y-%m-%d').log"
  LOCK_FILE="${CONTROL_DIR}/cleanup_sent.lock"

  touch "${SENT_DIR}/.keep"
}

validate_safe_paths() {
  if [ -z "${CAM_ID:-}" ]; then
    error "CAM_ID vazio. Abortando."
    exit 1
  fi

  if [ "$SENT_DIR" = "/" ] || [ "$SENT_DIR" = "/var" ] || [ "$SENT_DIR" = "/var/photo-spool" ]; then
    error "Caminho inseguro detectado: $SENT_DIR"
    exit 1
  fi

  if [ ! -d "$SENT_DIR" ]; then
    error "Pasta enviados não existe: $SENT_DIR"
    exit 1
  fi
}

main() {
  load_config

  exec > >(tee -a "$LOG_FILE") 2>&1

  exec 9>"$LOCK_FILE"

  if ! flock -n 9; then
    warn "Outra limpeza já está em andamento. Saindo."
    exit 0
  fi

  validate_safe_paths

  log "============================================================"
  log "Photo Uploader - Cleanup Sent iniciado"
  log "CAM_ID: $CAM_ID"
  log "Pasta enviados: $SENT_DIR"
  log "Limite para limpeza: ${THRESHOLD_SESSIONS} sessões"
  log "Manter últimas: ${KEEP_LATEST}"
  log "DRY_RUN: ${DRY_RUN}"
  log "============================================================"

  mapfile -t sessions < <(
    find "$SENT_DIR" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d \
      -printf '%f\n' \
      | sort
  )

  SESSION_COUNT="${#sessions[@]}"

  log "Sessões encontradas em enviados/: $SESSION_COUNT"

  if [ "$SESSION_COUNT" -lt "$THRESHOLD_SESSIONS" ]; then
    log "Abaixo do limite. Nada será apagado."
    log "============================================================"
    exit 0
  fi

  DELETE_COUNT=$((SESSION_COUNT - KEEP_LATEST))

  log "Limite atingido. Serão removidas ${DELETE_COUNT} sessão(ões) antiga(s)."

  for ((i=0; i<DELETE_COUNT; i++)); do
    session="${sessions[$i]}"
    session_path="${SENT_DIR}/${session}"

    if [ ! -d "$session_path" ]; then
      warn "Sessão não encontrada no momento da limpeza: $session_path"
      continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
      warn "[DRY_RUN] Apagaria: $session_path"
    else
      log "Apagando sessão antiga: $session_path"
      rm -rf -- "$session_path"
    fi
  done

  touch "${SENT_DIR}/.keep"

  log "Limpeza finalizada."
  log "Sessões mantidas após regra:"

  find "$SENT_DIR" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -printf ' - %f\n' \
    | sort

  log "============================================================"
}

main "$@"
