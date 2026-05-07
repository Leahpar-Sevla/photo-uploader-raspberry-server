#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/photo-server/rasps.conf"
DEST_BASE="${DEST_BASE:-/srv/server/EXTERNAS}"

CONTROL_DIR="${DEST_BASE}/.controle"
DOWNLOADED_LOG="${CONTROL_DIR}/baixados.log"
ERROR_LOG="${CONTROL_DIR}/erros.log"
MAIN_LOG="${CONTROL_DIR}/pull_externas.log"
LOCK_FILE="${CONTROL_DIR}/pull.lock"
SSH_CONNECT_TIMEOUT="8"

now() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(now)] [INFO] $*"; }
warn() { echo "[$(now)] [WARN] $*"; }
error() { echo "[$(now)] [ERROR] $*"; }

append_error() {
  local cam_id="$1"
  local session="$2"
  local message="$3"
  echo "$(now)|${cam_id}|${session}|${message}" >> "$ERROR_LOG"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    error "Missing command: $1"
    exit 1
  }
}

is_downloaded() {
  local cam_id="$1"
  local session="$2"
  grep -Fq "|${cam_id}|${session}|" "$DOWNLOADED_LOG" 2>/dev/null
}

mark_downloaded() {
  local cam_id="$1"
  local session="$2"
  local remote_path="$3"
  local final_path="$4"
  local file_count="$5"
  echo "$(now)|${cam_id}|${session}|${remote_path}|${final_path}|FILES=${file_count}" >> "$DOWNLOADED_LOG"
}

prepare_environment() {
  mkdir -p "$DEST_BASE" "$CONTROL_DIR"
  touch "$DOWNLOADED_LOG" "$ERROR_LOG" "$MAIN_LOG"

  for cmd in rsync ssh find flock grep basename wc; do
    require_command "$cmd"
  done
}

test_ssh_connection() {
  local ssh_user="$1"
  local host="$2"
  local ssh_key="$3"

  ssh \
    -i "$ssh_key" \
    -o BatchMode=yes \
    -o ConnectTimeout="$SSH_CONNECT_TIMEOUT" \
    -o StrictHostKeyChecking=accept-new \
    "${ssh_user}@${host}" \
    "hostname" >/dev/null 2>&1
}

list_ready_sessions() {
  local ssh_user="$1"
  local host="$2"
  local ssh_key="$3"
  local remote_pending="$4"

  ssh \
    -i "$ssh_key" \
    -o BatchMode=yes \
    -o ConnectTimeout="$SSH_CONNECT_TIMEOUT" \
    -o StrictHostKeyChecking=accept-new \
    "${ssh_user}@${host}" \
    "find '${remote_pending}' -mindepth 2 -maxdepth 2 -name .READY -printf '%h\n' 2>/dev/null | sort"
}

move_remote_to_sent() {
  local ssh_user="$1"
  local host="$2"
  local ssh_key="$3"
  local remote_session="$4"
  local remote_sent="$5"
  local session="$6"

  ssh \
    -i "$ssh_key" \
    -o BatchMode=yes \
    -o ConnectTimeout="$SSH_CONNECT_TIMEOUT" \
    -o StrictHostKeyChecking=accept-new \
    "${ssh_user}@${host}" \
    "mkdir -p '${remote_sent}' && if [ -e '${remote_sent}/${session}' ]; then exit 20; fi && mv '${remote_session}' '${remote_sent}/${session}'"
}

apply_permissions() {
  local final_dir="$1"
  find "$final_dir" -type d -exec chmod 775 {} \;
  find "$final_dir" -type f -exec chmod 664 {} \;
}

process_session() {
  local cam_id="$1"
  local ssh_user="$2"
  local host="$3"
  local remote_base="$4"
  local ssh_key="$5"
  local remote_session="$6"

  local session
  session="$(basename "$remote_session")"

  local cam_dest_dir="${DEST_BASE}/${cam_id}"
  local tmp_root="${cam_dest_dir}/.tmp"
  local tmp_dir="${tmp_root}/${session}.partial.$$"
  local final_dir="${cam_dest_dir}/${session}"
  local remote_sent="${remote_base}/enviados"

  mkdir -p "$tmp_root"

  log "Ready session found: ${cam_id}/${session}"

  if is_downloaded "$cam_id" "$session"; then
    log "Already registered as downloaded. Skipping: ${cam_id}/${session}"
    return 0
  fi

  if [ -e "$final_dir" ]; then
    if [ -f "${final_dir}/.PULLED_BY_SERVER" ]; then
      warn "Final folder already exists with marker. Registering and skipping: $final_dir"
      mark_downloaded "$cam_id" "$session" "$remote_session" "$final_dir" "ALREADY_EXISTS"
      return 0
    fi

    error "Final folder exists without marker. Manual review needed: $final_dir"
    append_error "$cam_id" "$session" "Final folder exists without marker: $final_dir"
    return 1
  fi

  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"

  log "Copying to temporary folder: $tmp_dir"

  if ! rsync -a \
    --human-readable \
    --partial \
    --partial-dir=".rsync-partial" \
    -e "ssh -i ${ssh_key} -o BatchMode=yes -o ConnectTimeout=${SSH_CONNECT_TIMEOUT} -o StrictHostKeyChecking=accept-new" \
    "${ssh_user}@${host}:${remote_session}/" \
    "${tmp_dir}/"; then

    error "rsync failed: ${cam_id}/${session}"
    append_error "$cam_id" "$session" "rsync failed"
    rm -rf "$tmp_dir"
    return 1
  fi

  if [ ! -f "${tmp_dir}/.READY" ]; then
    error "Copied session has no .READY. Aborting: ${cam_id}/${session}"
    append_error "$cam_id" "$session" "copied session has no .READY"
    rm -rf "$tmp_dir"
    return 1
  fi

  local file_count
  file_count="$(find "$tmp_dir" -type f ! -name ".READY" | wc -l | tr -d ' ')"

  if [ "$file_count" -lt 1 ]; then
    error "Session has no useful files. Aborting: ${cam_id}/${session}"
    append_error "$cam_id" "$session" "session has no useful files"
    rm -rf "$tmp_dir"
    return 1
  fi

  log "Moving temporary folder to final folder: $final_dir"
  mv "$tmp_dir" "$final_dir"

  cat > "${final_dir}/.PULLED_BY_SERVER" <<EOF
CAM_ID=${cam_id}
SESSION=${session}
SOURCE_HOST=${host}
SOURCE_PATH=${remote_session}
DEST_PATH=${final_dir}
PULLED_AT=$(now)
FILE_COUNT=${file_count}
EOF

  apply_permissions "$final_dir"
  mark_downloaded "$cam_id" "$session" "$remote_session" "$final_dir" "$file_count"

  log "Moving remote session to enviados/: ${cam_id}/${session}"

  if move_remote_to_sent "$ssh_user" "$host" "$ssh_key" "$remote_session" "$remote_sent" "$session"; then
    log "Remote session moved to enviados/: ${cam_id}/${session}"
  else
    warn "Downloaded, but failed to move remote session to enviados/: ${cam_id}/${session}"
    append_error "$cam_id" "$session" "downloaded but failed to move remote session to enviados"
  fi
}

process_rasp() {
  local cam_id="$1"
  local ssh_user="$2"
  local host="$3"
  local remote_base="$4"
  local ssh_key="$5"
  local remote_pending="${remote_base}/pendentes"

  log "------------------------------------------------------------"
  log "Processing Raspberry: CAM_ID=${cam_id} HOST=${host}"

  mkdir -p "${DEST_BASE}/${cam_id}"

  if [ ! -f "$ssh_key" ]; then
    error "SSH key not found: $ssh_key"
    append_error "$cam_id" "-" "SSH key not found: $ssh_key"
    return 1
  fi

  if ! test_ssh_connection "$ssh_user" "$host" "$ssh_key"; then
    warn "Raspberry offline or SSH unavailable: ${cam_id} (${host})"
    append_error "$cam_id" "-" "Raspberry offline or SSH unavailable: ${host}"
    return 0
  fi

  local sessions
  sessions="$(list_ready_sessions "$ssh_user" "$host" "$ssh_key" "$remote_pending" || true)"

  if [ -z "$sessions" ]; then
    log "No .READY sessions found for ${cam_id}"
    return 0
  fi

  while IFS= read -r remote_session; do
    [ -z "$remote_session" ] && continue
    process_session "$cam_id" "$ssh_user" "$host" "$remote_base" "$ssh_key" "$remote_session" || true
  done <<< "$sessions"
}

main() {
  prepare_environment

  exec > >(tee -a "$MAIN_LOG") 2>&1
  exec 9>"$LOCK_FILE"

  if ! flock -n 9; then
    warn "Another pull execution is already running. Exiting."
    exit 0
  fi

  log "============================================================"
  log "Photo Server - Pull EXTERNAS started"
  log "Config: $CONFIG_FILE"
  log "Destination: $DEST_BASE"
  log "Control: $CONTROL_DIR"
  log "============================================================"

  if [ ! -f "$CONFIG_FILE" ]; then
    error "Config not found: $CONFIG_FILE"
    exit 1
  fi

  while IFS='|' read -r cam_id ssh_user host remote_base ssh_key extra; do
    [[ -z "${cam_id// }" ]] && continue
    [[ "$cam_id" =~ ^# ]] && continue

    if [ -n "${extra:-}" ]; then
      warn "Line has extra fields. Ignoring extras for CAM_ID=${cam_id}"
    fi

    if [ -z "${cam_id:-}" ] || [ -z "${ssh_user:-}" ] || [ -z "${host:-}" ] || [ -z "${remote_base:-}" ] || [ -z "${ssh_key:-}" ]; then
      warn "Invalid line in $CONFIG_FILE. Skipping."
      continue
    fi

    process_rasp "$cam_id" "$ssh_user" "$host" "$remote_base" "$ssh_key"
  done < "$CONFIG_FILE"

  log "Photo Server - Pull EXTERNAS finished"
  log "============================================================"
}

main "$@"
