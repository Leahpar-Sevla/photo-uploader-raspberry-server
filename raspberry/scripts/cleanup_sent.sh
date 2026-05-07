#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/photo-uploader/config.env"
THRESHOLD_SESSIONS=10
KEEP_LATEST=1
DRY_RUN="${DRY_RUN:-0}"

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
    error "CAM_ID is empty. Aborting."
    exit 1
  fi

  case "$SENT_DIR" in
    "/"|"/var"|"/var/photo-spool")
      error "Unsafe path detected: $SENT_DIR"
      exit 1
      ;;
  esac

  [ -d "$SENT_DIR" ] || {
    error "Sent folder does not exist: $SENT_DIR"
    exit 1
  }
}

main() {
  load_config

  exec > >(tee -a "$LOG_FILE") 2>&1
  exec 9>"$LOCK_FILE"

  if ! flock -n 9; then
    warn "Another cleanup is already running. Exiting."
    exit 0
  fi

  validate_safe_paths

  log "Cleanup started"
  log "CAM_ID: $CAM_ID"
  log "Sent folder: $SENT_DIR"
  log "Threshold: $THRESHOLD_SESSIONS"
  log "Keep latest: $KEEP_LATEST"
  log "DRY_RUN: $DRY_RUN"

  mapfile -t sessions < <(
    find "$SENT_DIR" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d \
      -printf '%f\n' \
      | sort
  )

  SESSION_COUNT="${#sessions[@]}"

  log "Sessions found: $SESSION_COUNT"

  if [ "$SESSION_COUNT" -lt "$THRESHOLD_SESSIONS" ]; then
    log "Below threshold. Nothing will be deleted."
    exit 0
  fi

  DELETE_COUNT=$((SESSION_COUNT - KEEP_LATEST))
  log "Threshold reached. Old sessions to remove: $DELETE_COUNT"

  for ((i=0; i<DELETE_COUNT; i++)); do
    session="${sessions[$i]}"
    session_path="${SENT_DIR}/${session}"

    if [ "$DRY_RUN" = "1" ]; then
      warn "[DRY_RUN] Would delete: $session_path"
    else
      log "Deleting old session: $session_path"
      rm -rf -- "$session_path"
    fi
  done

  touch "${SENT_DIR}/.keep"

  log "Cleanup completed."
  find "$SENT_DIR" -mindepth 1 -maxdepth 1 -type d -printf ' - %f\n' | sort
}

main "$@"
