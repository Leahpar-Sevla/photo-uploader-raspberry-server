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

check_commands() {
  for cmd in gphoto2 flock awk grep find sort stat mktemp wc; do
    command -v "$cmd" >/dev/null 2>&1 || {
      echo "[ERRO] comando ausente: $cmd"
      exit 1
    }
  done
}

load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERRO] config não encontrado: $CONFIG_FILE"
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  CAM_ID="${CAM_ID:-CAM-01}"
  LOCAL_BASE="${LOCAL_BASE:-/var/photo-spool}"

  BASE_CAM="${LOCAL_BASE}/${CAM_ID}"

  IMPORTING_DIR="${BASE_CAM}/importando"
  PENDING_DIR="${BASE_CAM}/pendentes"
  ERROR_DIR="${BASE_CAM}/erro"
  LOG_DIR="${BASE_CAM}/logs"
  CONTROL_DIR="${BASE_CAM}/controle"

  mkdir -p "$IMPORTING_DIR" "$PENDING_DIR" "$ERROR_DIR" "$LOG_DIR" "$CONTROL_DIR"

  LOCK_FILE="${CONTROL_DIR}/import.lock"
  HISTORY_FILE="${CONTROL_DIR}/camera_imported_files.tsv"
}

detect_camera() {
  log "Verificando câmera conectada..."

  if ! gphoto2 --auto-detect | awk 'NR>2 {found=1} END {exit found ? 0 : 1}'; then
    warn "Nenhuma câmera detectada pelo gphoto2."
    if [ -n "${SESSION_DIR_TMP:-}" ] && [ -d "$SESSION_DIR_TMP" ]; then
      rmdir "$SESSION_DIR_TMP" 2>/dev/null || true
    fi
    exit 0
  fi

  log "Câmera detectada."
}

list_camera_files() {
  CAMERA_RAW="$(mktemp)"
  CAMERA_INV="$(mktemp)"

  log "Listando arquivos da câmera..."
  gphoto2 --list-files > "$CAMERA_RAW"

  awk '
    /^#[0-9]+[[:space:]]/ {
      num=$1
      sub(/^#/, "", num)

      name=$2
      size=$4
      unit=$5
      ts=$7

      if (name == "") next
      if (size == "") size="0"
      if (unit == "") unit="B"
      if (ts == "") ts="0"

      sizeunit=size unit

      print num "\t" name "\t" sizeunit "\t" ts
    }
  ' "$CAMERA_RAW" > "$CAMERA_INV"

  CAMERA_COUNT="$(wc -l < "$CAMERA_INV" | tr -d ' ')"
  log "Arquivos encontrados na câmera: $CAMERA_COUNT"
}

build_history_keys() {
  HISTORY_KEYS="$(mktemp)"
  touch "$HISTORY_FILE"

  awk -F'\t' 'NF >= 3 {print $1 "\t" $2 "\t" $3}' "$HISTORY_FILE" > "$HISTORY_KEYS"
}

build_new_list() {
  NEW_FILES="$(mktemp)"
  : > "$NEW_FILES"

  build_history_keys

  while IFS=$'\t' read -r num name sizeunit ts; do
    [ -z "${name:-}" ] && continue

    key="$(printf '%s\t%s\t%s' "$name" "$sizeunit" "$ts")"

    if grep -Fqx "$key" "$HISTORY_KEYS"; then
      continue
    fi

    printf '%s\t%s\t%s\t%s\n' "$num" "$name" "$sizeunit" "$ts" >> "$NEW_FILES"
  done < "$CAMERA_INV"

  NEW_COUNT="$(wc -l < "$NEW_FILES" | tr -d ' ')"
  log "Arquivos novos para importar: $NEW_COUNT"
}

create_session() {
  TS="$(date '+%Y-%m-%d_%H%M%S')"
  SESSION="${CAM_ID}_${TS}"

  SESSION_DIR_TMP="${IMPORTING_DIR}/${SESSION}"
  SESSION_DIR_FINAL="${PENDING_DIR}/${SESSION}"
  LOG_FILE="${LOG_DIR}/import_incremental_${SESSION}.log"

  mkdir -p "$SESSION_DIR_TMP"
}

download_new_files() {
  NEW_HISTORY_ENTRIES="$(mktemp)"

  local seq=1

  while IFS=$'\t' read -r num name sizeunit ts; do
    [ -z "${name:-}" ] && continue

    out_name="$(printf '%03d_%s' "$seq" "$name")"

    log "Baixando novo arquivo #${num}: ${name} -> ${out_name}"

    if ! gphoto2 --get-file "$num" --filename "${SESSION_DIR_TMP}/${out_name}"; then
      fail_session "Falha durante cópia incremental via gphoto2."
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$sizeunit" "$ts" "$SESSION" "$(now)" >> "$NEW_HISTORY_ENTRIES"

    seq=$((seq + 1))
  done < "$NEW_FILES"

  FILE_COUNT="$(find "$SESSION_DIR_TMP" -maxdepth 1 -type f | wc -l | tr -d ' ')"

  log "Arquivos baixados nesta sessão: $FILE_COUNT"

  if [ "$FILE_COUNT" -lt 1 ]; then
    fail_session "Nenhum arquivo novo foi copiado."
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
    echo "MODE=incremental"
    echo "HISTORY_FILE=${HISTORY_FILE}"
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
    fail_session "Já existe sessão em pendentes/: $SESSION_DIR_FINAL"
  fi

  log "Movendo sessão para pendentes/: $SESSION_DIR_FINAL"
  mv "$SESSION_DIR_TMP" "$SESSION_DIR_FINAL"
}

update_history() {
  log "Atualizando histórico incremental: $HISTORY_FILE"
  cat "$NEW_HISTORY_ENTRIES" >> "$HISTORY_FILE"
}

seed_current_camera() {
  TS="$(date '+%Y-%m-%d_%H%M%S')"
  LOG_FILE="${LOG_DIR}/seed_camera_history_${CAM_ID}_${TS}.log"

  exec > >(tee -a "$LOG_FILE") 2>&1

  exec 9>"$LOCK_FILE"

  if ! flock -n 9; then
    warn "Outra importação já está em andamento. Saindo."
    exit 0
  fi

  log "============================================================"
  log "Photo Uploader - Seed histórico incremental"
  log "CAM_ID: $CAM_ID"
  log "Log: $LOG_FILE"
  log "============================================================"

  detect_camera
  list_camera_files
  build_history_keys

  SEED_COUNT=0

  while IFS=$'\t' read -r num name sizeunit ts; do
    [ -z "${name:-}" ] && continue

    key="$(printf '%s\t%s\t%s' "$name" "$sizeunit" "$ts")"

    if grep -Fqx "$key" "$HISTORY_KEYS"; then
      continue
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$sizeunit" "$ts" "SEEDED" "$(now)" >> "$HISTORY_FILE"
    printf '%s\n' "$key" >> "$HISTORY_KEYS"
    SEED_COUNT=$((SEED_COUNT + 1))
  done < "$CAMERA_INV"

  log "Arquivos marcados como já conhecidos: $SEED_COUNT"
  log "Seed finalizado."
  log "Histórico: $HISTORY_FILE"
  log "============================================================"
}

main_import() {
  create_session

  exec > >(tee -a "$LOG_FILE") 2>&1

  exec 9>"$LOCK_FILE"

  if ! flock -n 9; then
    warn "Outra importação já está em andamento. Saindo."
    exit 0
  fi

  log "============================================================"
  log "Photo Uploader - Importação incremental da câmera"
  log "CAM_ID: $CAM_ID"
  log "Sessão: $SESSION"
  log "Base local: $BASE_CAM"
  log "Log: $LOG_FILE"
  log "Histórico: $HISTORY_FILE"
  log "============================================================"

  detect_camera
  list_camera_files
  build_new_list

  if [ "$NEW_COUNT" -lt 1 ]; then
    warn "Nenhum arquivo novo encontrado. Removendo sessão vazia."
    rmdir "$SESSION_DIR_TMP" 2>/dev/null || true
    log "Nada para importar."
    log "============================================================"
    exit 0
  fi

  download_new_files
  create_manifest
  mark_ready
  move_to_pending
  update_history

  log "Importação incremental finalizada com sucesso."
  log "Sessão pronta para o servidor buscar:"
  log "$SESSION_DIR_FINAL"
  log "============================================================"
}

check_commands
load_config

case "${1:-}" in
  --seed-current)
    seed_current_camera
    ;;
  "")
    main_import
    ;;
  *)
    echo "Uso:"
    echo "  $0"
    echo "  $0 --seed-current"
    exit 1
    ;;
esac
