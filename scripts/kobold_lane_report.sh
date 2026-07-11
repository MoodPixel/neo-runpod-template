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

cat > "$REPORT_MD" <<EOF
# KoboldCPP lane report

Generated: $(ts)

## Current config

| Key | Value |
|---|---|
| START_KOBOLD | ${START_KOBOLD:-0} |
| INSTALL_KOBOLD | ${INSTALL_KOBOLD:-0} |
| KOBOLD_MODE | ${KOBOLD_MODE:-optional} |
| KOBOLD_STRICT | ${KOBOLD_STRICT:-0} |
| KOBOLD_SUPERVISED | ${KOBOLD_SUPERVISED:-0} |
| KOBOLDCPP_BIN | $KOBOLDCPP_BIN |
| KOBOLD_MODEL | $KOBOLD_MODEL |
| KOBOLD API | $KOBOLD_URL |

## Fast diagnosis

EOF

if [[ ! -x "$KOBOLDCPP_BIN" ]]; then
  cat >> "$REPORT_MD" <<EOF
- Missing KoboldCPP binary.
- Fix: set `INSTALL_KOBOLD=1` and `KOBOLDCPP_URL` to a direct Linux binary URL, or copy an executable to `$KOBOLDCPP_BIN`.

EOF
fi

if [[ ! -f "$KOBOLD_MODEL" ]]; then
  cat >> "$REPORT_MD" <<EOF
- Missing configured text GGUF model.
- Fix: download a `.gguf` text model into `/workspace/neo-models/text`, then set `KOBOLD_MODEL` to the exact file path.

EOF
fi

if [[ "$http_status" != "200" ]]; then
  cat >> "$REPORT_MD" <<EOF
- Kobold API is not ready at `$KOBOLD_URL`.
- Check `/workspace/logs/koboldcpp.log` after binary/model are present.

EOF
fi

cat >> "$REPORT_MD" <<EOF
## Useful commands

```bash
cat /workspace/logs/koboldcpp_status.env
cat /workspace/logs/koboldcpp_runtime_status.env
cat /workspace/logs/koboldcpp_check_summary.env
cat /workspace/logs/koboldcpp_check.tsv
tail -n 200 /workspace/logs/koboldcpp.log
find /workspace/neo-models/text -maxdepth 2 -type f -iname '*.gguf' -print
```

## Report files

```text
$REPORT_MD
$REPORT_TSV
```
EOF

printf '[kobold-lane-report] Wrote %s and %s\n' "$REPORT_MD" "$REPORT_TSV"
