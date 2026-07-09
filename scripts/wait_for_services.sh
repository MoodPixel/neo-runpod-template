#!/usr/bin/env bash
set -Eeuo pipefail

TIMEOUT_SECONDS="${HEALTH_WAIT_TIMEOUT_SECONDS:-300}"
INTERVAL_SECONDS="${HEALTH_WAIT_INTERVAL_SECONDS:-5}"
LOG_FILE="${HEALTH_WAIT_LOG_FILE:-/workspace/logs/wait_for_services.log}"
HEALTHCHECK_SCRIPT="${HEALTHCHECK_SCRIPT:-/opt/neo-runpod/scripts/healthcheck.sh}"

mkdir -p /workspace/logs
: > "$LOG_FILE"

log() {
  local message="$*"
  printf '[wait-for-services] %s\n' "$message" | tee -a "$LOG_FILE"
}

if [[ ! -x "$HEALTHCHECK_SCRIPT" ]]; then
  log "Healthcheck script missing or not executable: $HEALTHCHECK_SCRIPT"
  exit 1
fi

start_epoch="$(date +%s)"
end_epoch=$((start_epoch + TIMEOUT_SECONDS))
attempt=0

log "Waiting up to ${TIMEOUT_SECONDS}s for services. Interval: ${INTERVAL_SECONDS}s"

while true; do
  attempt=$((attempt + 1))
  now="$(date +%s)"

  log "Attempt ${attempt}"
  if "$HEALTHCHECK_SCRIPT" >> "$LOG_FILE" 2>&1; then
    log "Services ready"
    exit 0
  fi

  if [[ "$now" -ge "$end_epoch" ]]; then
    log "Timed out waiting for services"
    log "Latest health report: ${HEALTH_REPORT_FILE:-/workspace/logs/healthcheck.tsv}"
    exit 1
  fi

  sleep "$INTERVAL_SECONDS"
done
