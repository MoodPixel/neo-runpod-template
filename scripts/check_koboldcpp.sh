#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[check-koboldcpp] %s\n' "$*"
}

KOBOLDCPP_ROOT="${KOBOLDCPP_ROOT:-/workspace/koboldcpp}"
KOBOLDCPP_BIN="${KOBOLDCPP_BIN:-$KOBOLDCPP_ROOT/koboldcpp-linux-x64}"
KOBOLD_MODEL="${KOBOLD_MODEL:-/workspace/neo-models/text/model.gguf}"
KOBOLD_PORT="${KOBOLD_PORT:-5001}"
KOBOLD_REPORT_FILE="${KOBOLD_REPORT_FILE:-/workspace/logs/koboldcpp_check.tsv}"
KOBOLD_MODE="${KOBOLD_MODE:-optional}"

mkdir -p /workspace/logs
: > "$KOBOLD_REPORT_FILE"
printf 'check\tstatus\tdetail\n' >> "$KOBOLD_REPORT_FILE"

record() {
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$KOBOLD_REPORT_FILE"
}

missing=0

if [[ "${START_KOBOLD:-0}" != "1" ]]; then
  record "start_toggle" "disabled" "START_KOBOLD=0"
  log "START_KOBOLD=0; KoboldCPP lane is disabled"
  log "Report: $KOBOLD_REPORT_FILE"
  exit 0
fi

if [[ -x "$KOBOLDCPP_BIN" ]]; then
  record "binary" "present" "$KOBOLDCPP_BIN"
else
  record "binary" "missing" "$KOBOLDCPP_BIN"
  missing=$((missing + 1))
fi

if [[ -f "$KOBOLD_MODEL" ]]; then
  record "model" "present" "$KOBOLD_MODEL"
else
  record "model" "missing" "$KOBOLD_MODEL"
  missing=$((missing + 1))
fi

if curl -fsS --max-time 5 "http://127.0.0.1:${KOBOLD_PORT}/v1/models" >/dev/null 2>&1; then
  record "api" "ready" "http://127.0.0.1:${KOBOLD_PORT}/v1/models"
else
  record "api" "not_ready" "http://127.0.0.1:${KOBOLD_PORT}/v1/models"
  if [[ "${CHECK_KOBOLD_API_REQUIRED:-0}" == "1" ]]; then
    missing=$((missing + 1))
  fi
fi

log "Report: $KOBOLD_REPORT_FILE"
if [[ "$missing" -gt 0 ]]; then
  log "KoboldCPP missing/failed check count: $missing"
  if [[ "$KOBOLD_MODE" == "required" || "${KOBOLD_STRICT:-0}" == "1" ]]; then
    exit 1
  fi
fi

exit 0
