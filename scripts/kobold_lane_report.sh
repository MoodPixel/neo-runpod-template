#!/usr/bin/env bash
set -Eeuo pipefail

REPORT_MD="${KOBOLD_LANE_REPORT_MD:-/workspace/logs/kobold_lane_report.md}"
REPORT_TSV="${KOBOLD_LANE_REPORT_TSV:-/workspace/logs/kobold_lane_report.tsv}"
KOBOLDCPP_ROOT="${KOBOLDCPP_ROOT:-/workspace/koboldcpp}"
KOBOLDCPP_BIN="${KOBOLDCPP_BIN:-$KOBOLDCPP_ROOT/koboldcpp-linux-x64}"
KOBOLD_MODEL="${KOBOLD_MODEL:-/workspace/neo-models/text/model.gguf}"
KOBOLD_PORT="${KOBOLD_PORT:-5001}"
KOBOLD_URL="http://127.0.0.1:${KOBOLD_PORT}/v1/models"

mkdir -p /workspace/logs /workspace/neo-models/text
: > "$REPORT_TSV"
printf 'item\tstatus\tdetail\n' >> "$REPORT_TSV"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
record() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$REPORT_TSV"; }
flag() { [[ "${1:-}" == "1" ]] && printf 'enabled' || printf 'disabled'; }
set_state() { [[ -n "${1:-}" ]] && printf 'set' || printf 'unset'; }

record "START_KOBOLD" "$(flag "${START_KOBOLD:-0}")" "runtime launch toggle"
record "INSTALL_KOBOLD" "$(flag "${INSTALL_KOBOLD:-0}")" "startup binary download toggle"
record "KOBOLD_MODE" "${KOBOLD_MODE:-optional}" "optional or required"
record "KOBOLD_STRICT" "$(flag "${KOBOLD_STRICT:-0}")" "strict failure mode"
record "KOBOLD_SUPERVISED" "$(flag "${KOBOLD_SUPERVISED:-0}")" "process supervision mode"
record "KOBOLDCPP_URL" "$(set_state "${KOBOLDCPP_URL:-}")" "direct binary download URL state only"

if [[ -x "$KOBOLDCPP_BIN" ]]; then
  record "binary" "present" "$KOBOLDCPP_BIN"
else
  record "binary" "missing" "$KOBOLDCPP_BIN"
fi

if [[ -f "$KOBOLD_MODEL" ]]; then
  record "configured_model" "present" "$KOBOLD_MODEL"
else
  record "configured_model" "missing" "$KOBOLD_MODEL"
fi

candidate_count=0
while IFS= read -r candidate; do
  [[ -n "$candidate" ]] || continue
  candidate_count=$((candidate_count + 1))
  record "gguf_candidate" "found" "$candidate"
done < <(find /workspace/neo-models/text -maxdepth 2 -type f -iname '*.gguf' 2>/dev/null | sort | head -n 30)
if [[ "$candidate_count" -eq 0 ]]; then
  record "gguf_candidate" "none" "/workspace/neo-models/text"
fi

http_status="000"
if command -v curl >/dev/null 2>&1; then
  http_status="$(curl -sS -o /tmp/kobold_lane_models.json -w '%{http_code}' --max-time 5 "$KOBOLD_URL" 2>/tmp/kobold_lane_models.err || true)"
fi
if [[ "$http_status" == "200" ]]; then
  record "api" "ready" "$KOBOLD_URL"
else
  err=""
  if [[ -s /tmp/kobold_lane_models.err ]]; then
    err=" $(tr '\n' ' ' < /tmp/kobold_lane_models.err | head -c 240)"
  fi
  record "api" "not_ready" "$KOBOLD_URL http_status=$http_status$err"
fi

{
  printf '# KoboldCPP lane report\n\n'
  printf 'Generated: %s\n\n' "$(ts)"
  printf '## Current config\n\n'
  printf '| Key | Value |\n|---|---|\n'
  printf '| START_KOBOLD | %s |\n' "${START_KOBOLD:-0}"
  printf '| INSTALL_KOBOLD | %s |\n' "${INSTALL_KOBOLD:-0}"
  printf '| KOBOLD_MODE | %s |\n' "${KOBOLD_MODE:-optional}"
  printf '| KOBOLD_STRICT | %s |\n' "${KOBOLD_STRICT:-0}"
  printf '| KOBOLD_SUPERVISED | %s |\n' "${KOBOLD_SUPERVISED:-0}"
  printf '| KOBOLDCPP_BIN | %s |\n' "$KOBOLDCPP_BIN"
  printf '| KOBOLD_MODEL | %s |\n' "$KOBOLD_MODEL"
  printf '| KOBOLD API | %s |\n\n' "$KOBOLD_URL"
  printf '## Fast diagnosis\n\n'
} > "$REPORT_MD"

if [[ ! -x "$KOBOLDCPP_BIN" ]]; then
  {
    printf -- '- Missing KoboldCPP binary.\n'
    printf -- '- Fix: set INSTALL_KOBOLD=1 and KOBOLDCPP_URL to a direct Linux binary URL, or copy an executable to %s.\n\n' "$KOBOLDCPP_BIN"
  } >> "$REPORT_MD"
fi

if [[ ! -f "$KOBOLD_MODEL" ]]; then
  {
    printf -- '- Missing configured text GGUF model.\n'
    printf -- '- Fix: download a .gguf text model into /workspace/neo-models/text, then set KOBOLD_MODEL to the exact file path.\n\n'
  } >> "$REPORT_MD"
fi

if [[ "$http_status" != "200" ]]; then
  {
    printf -- '- Kobold API is not ready at %s.\n' "$KOBOLD_URL"
    printf -- '- Check /workspace/logs/koboldcpp.log after binary/model are present.\n\n'
  } >> "$REPORT_MD"
fi

cat >> "$REPORT_MD" <<'EOF'
## Useful commands

```bash
cat /workspace/logs/koboldcpp_status.env
cat /workspace/logs/koboldcpp_runtime_status.env
cat /workspace/logs/koboldcpp_check_summary.env
cat /workspace/logs/koboldcpp_check.tsv
tail -n 200 /workspace/logs/koboldcpp.log
find /workspace/neo-models/text -maxdepth 2 -type f -iname '*.gguf' -print
```

EOF
{
  printf '## Report files\n\n'
  printf '```text\n%s\n%s\n```\n' "$REPORT_MD" "$REPORT_TSV"
} >> "$REPORT_MD"

printf '[kobold-lane-report] Wrote %s and %s\n' "$REPORT_MD" "$REPORT_TSV"
