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
KOBOLD_SUMMARY_FILE="${KOBOLD_SUMMARY_FILE:-/workspace/logs/koboldcpp_check_summary.env}"
KOBOLD_MODE="${KOBOLD_MODE:-optional}"
KOBOLD_URL="http://127.0.0.1:${KOBOLD_PORT}/v1/models"

mkdir -p /workspace/logs /workspace/neo-models/text
: > "$KOBOLD_REPORT_FILE"
printf 'check\tstatus\tdetail\n' >> "$KOBOLD_REPORT_FILE"

record() {
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$KOBOLD_REPORT_FILE"
}

missing=0
warnings=0
api_required="${CHECK_KOBOLD_API_REQUIRED:-0}"
strict="${KOBOLD_STRICT:-0}"

record "start_toggle" "${START_KOBOLD:-0}" "START_KOBOLD controls runtime launch"
record "install_toggle" "${INSTALL_KOBOLD:-0}" "INSTALL_KOBOLD controls startup binary download"
record "mode" "$KOBOLD_MODE" "required/strict modes fail health checks"
record "supervised" "${KOBOLD_SUPERVISED:-0}" "supervised mode lets Kobold process exit stop the pod"

if [[ "${START_KOBOLD:-0}" != "1" ]]; then
  record "lane" "disabled" "START_KOBOLD=0"
  cat > "$KOBOLD_SUMMARY_FILE" <<EOF
KOBOLD_CHECK_STATUS=disabled
KOBOLD_CHECK_MISSING=0
KOBOLD_CHECK_WARNINGS=0
KOBOLD_REPORT_FILE=$KOBOLD_REPORT_FILE
KOBOLD_ACTION=Set START_KOBOLD=1 only after a binary and GGUF model are available.
EOF
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

candidate_count=0
while IFS= read -r model_path; do
  [[ -n "$model_path" ]] || continue
  candidate_count=$((candidate_count + 1))
  record "text_model_candidate" "found" "$model_path"
done < <(find /workspace/neo-models/text -maxdepth 2 -type f -iname '*.gguf' 2>/dev/null | sort | head -n 20)
if [[ "$candidate_count" -eq 0 ]]; then
  record "text_model_candidates" "none" "/workspace/neo-models/text/*.gguf"
fi

http_status="000"
if command -v curl >/dev/null 2>&1; then
  http_status="$(curl -sS -o /tmp/koboldcpp_models_probe.json -w '%{http_code}' --max-time 5 "$KOBOLD_URL" 2>/tmp/koboldcpp_models_probe.err || true)"
fi
if [[ "$http_status" == "200" ]]; then
  record "api" "ready" "$KOBOLD_URL"
else
  detail="$KOBOLD_URL http_status=$http_status"
  if [[ -s /tmp/koboldcpp_models_probe.err ]]; then
    detail="$detail error=$(tr '\n' ' ' < /tmp/koboldcpp_models_probe.err | head -c 240)"
  fi
  record "api" "not_ready" "$detail"
  if [[ "$api_required" == "1" ]]; then
    missing=$((missing + 1))
  else
    warnings=$((warnings + 1))
  fi
fi

status="ok"
action="Kobold lane appears ready."
if [[ "$missing" -gt 0 ]]; then
  status="missing_requirements"
  action="Install/copy KoboldCPP binary and download a text GGUF, then set KOBOLD_MODEL to the real GGUF path."
elif [[ "$warnings" -gt 0 ]]; then
  status="warning"
  action="Kobold requirements exist, but API is not ready yet. Check /workspace/logs/koboldcpp.log."
fi

cat > "$KOBOLD_SUMMARY_FILE" <<EOF
KOBOLD_CHECK_STATUS=$status
KOBOLD_CHECK_MISSING=$missing
KOBOLD_CHECK_WARNINGS=$warnings
KOBOLD_REPORT_FILE=$KOBOLD_REPORT_FILE
KOBOLDCPP_BIN=$KOBOLDCPP_BIN
KOBOLD_MODEL=$KOBOLD_MODEL
KOBOLD_API_URL=$KOBOLD_URL
KOBOLD_ACTION=$action
EOF

log "Report: $KOBOLD_REPORT_FILE"
log "Summary: $KOBOLD_SUMMARY_FILE"
if [[ "$missing" -gt 0 ]]; then
  log "KoboldCPP missing/failed check count: $missing"
  if [[ "$KOBOLD_MODE" == "required" || "$strict" == "1" ]]; then
    exit 1
  fi
fi

exit 0
