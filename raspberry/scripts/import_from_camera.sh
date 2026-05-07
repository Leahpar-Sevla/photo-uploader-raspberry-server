#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/photo-uploader/config.env"

now() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(now)] [INFO] $*"; }
warn() { echo "[$(now)] [WARN] $*"; }
error() { echo "[$(now)] [ERROR] $*"; }

load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    error "Config not found: $CONFIG_FILE"
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
  LOCK_FILE="${CONTROL_DIR}/import.lock"

  mkdir -p "$IMPORTING_DIR" "$PENDING_DIR" "$ERROR_DIR" "$LOG_DIR" "$CONTROL_DIR"
}

check_commands() {
  command -v gphoto2 >/dev/null 2>&1 || {
    error "gphoto2 not found. Install with: sudo apt install -y gphoto2"
    exit 1
  }

  command -v flock >/dev/null 2>&1 || {
    error "flock not found."
    exit 1
  }
}

detect_camera() {
  log "Checking camera..."

  if ! gphoto2 --auto-detect | awk 'NR>2 {found=1} END {exit found ? 0 : 1}'; then
    warn "No camera detected by gphoto2."
    exit 0
  fi

  log "Camera detected."
}

create_session() {
  TS="$(date '+%Y-%m-%d_%H%M%S')"
  SESSION="${CAM_ID}_${TS}"
  SESSION_DIR_TMP="${IMPORTING_DIR}/${SESSION}"
  SESSION_DIR_FINAL="${PENDING_DIR}/${SESSION}"
  LOG_FILE="${LOG_DIR}/import_${SESSION}.log"
  mkdir -p "$SESSION_DIR_TMP"
}

fail_session() {
  local reason="$1"
  error "$reason"

  if [ -n "${SESSION_DIR_TMP:-}" ] && [ -d "$SESSION_DIR_TMP" ]; then
    mkdir -p "$ERROR_DIR"
    mv "$SESSION_DIR_TMP" "${ERROR_DIR}/${SESSION}_FAILED_$(date '+%H%M%S')" || true
  fi

  exit 1
}

import_files() {
  log "Importing files to: $SESSION_DIR_TMP"
  pushd "$SESSION_DIR_TMP" >/dev/null
  gphoto2 --get-all-files --filename "%03n_%f.%C"
  popd >/dev/null

  FILE_COUNT="$(find "$SESSION_DIR_TMP" -type f | wc -l | tr -d ' ')"

  if [ "$FILE_COUNT" -lt 1 ]; then
    fail_session "No files imported from camera."
  fi

  log "Imported files: $FILE_COUNT"
}

create_manifest() {
  local manifest="${SESSION_DIR_TMP}/manifest.txt"

  {
    echo "SESSION=${SESSION}"
    echo "CAM_ID=${CAM_ID}"
    echo "IMPORT_DATE=$(now)"
    echo "HOSTNAME=$(hostname)"
    echo "SOURCE=gphoto2"
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

main() {
  check_commands
  load_config
  detect_camera
  create_session

  exec > >(tee -a "$LOG_FILE") 2>&1
  exec 9>"$LOCK_FILE"

  if ! flock -n 9; then
    warn "Another import is already running. Exiting."
    exit 0
  fi

  log "Starting import session: $SESSION"

  import_files
  create_manifest
  touch "${SESSION_DIR_TMP}/.READY"

  if [ -e "$SESSION_DIR_FINAL" ]; then
    fail_session "Final session already exists: $SESSION_DIR_FINAL"
  fi

  mv "$SESSION_DIR_TMP" "$SESSION_DIR_FINAL"

  log "Import completed."
  log "Ready session: $SESSION_DIR_FINAL"
}

main "$@"
