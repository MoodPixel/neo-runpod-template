#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="${RUNTIME_DIAGNOSTICS_DIR:-/workspace/logs/runtime_diagnostics}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_DIR/$TS"
mkdir -p "$RUN_DIR"

log() {
  printf '[runtime-diagnostics] %s\n' "$*"
}

write_cmd() {
  local name="$1"
  shift
  {
    printf '$ %q' "$1"
    shift || true
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n\n'
    "$@"
  } > "$RUN_DIR/$name" 2>&1 || true
}

check_url() {
  local name="$1"
  local url="$2"
  local code="000"
  code="$(curl -sS -o "$RUN_DIR/${name}.body" -w '%{http_code}' --max-time "${HEALTHCHECK_TIMEOUT:-5}" "$url" 2>"$RUN_DIR/${name}.err" || true)"
  printf '%s\t%s\t%s\n' "$name" "$code" "$url" >> "$RUN_DIR/service_http.tsv"
}

log "Writing diagnostics to $RUN_DIR"

cat > "$RUN_DIR/summary.env" <<EOF
RUNTIME_DIAGNOSTICS_STATUS=created
RUNTIME_DIAGNOSTICS_CREATED_AT=$TS
RUNTIME_DIAGNOSTICS_DIR=$RUN_DIR
NEO_ROOT=${NEO_ROOT:-/workspace/Neo_Studio_V2}
COMFY_ROOT=${COMFY_ROOT:-/workspace/ComfyUI}
MODEL_ROOT=${MODEL_ROOT:-/workspace/neo-models}
START_NEO=${START_NEO:-1}
START_COMFY=${START_COMFY:-1}
START_MODEL_DOWNLOADER=${START_MODEL_DOWNLOADER:-1}
START_KOBOLD=${START_KOBOLD:-0}
KOBOLD_MODEL=${KOBOLD_MODEL:-/workspace/neo-models/text/model.gguf}
EOF

printf 'service\thttp_status\turl\n' > "$RUN_DIR/service_http.tsv"
check_url "neo_health" "http://127.0.0.1:${NEO_PORT:-7860}/api/health"
check_url "comfy_system_stats" "http://127.0.0.1:${COMFY_PORT:-8188}/system_stats"
check_url "model_downloader_health" "http://127.0.0.1:${MODEL_DOWNLOADER_PORT:-7861}/health"
if [[ "${START_KOBOLD:-0}" == "1" ]]; then
  check_url "kobold_models" "http://127.0.0.1:${KOBOLD_PORT:-5001}/v1/models"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi > "$RUN_DIR/nvidia_smi.txt" 2>&1 || true
  nvidia-smi --query-gpu=timestamp,index,name,utilization.gpu,memory.used,memory.total,power.draw --format=csv > "$RUN_DIR/nvidia_smi_query.csv" 2>&1 || true
else
  printf 'nvidia-smi not found\n' > "$RUN_DIR/nvidia_smi.txt"
fi

if command -v df >/dev/null 2>&1; then
  df -h > "$RUN_DIR/df_h.txt" 2>&1 || true
fi
if command -v du >/dev/null 2>&1; then
  du -sh /workspace/neo-models /workspace/ComfyUI /workspace/Neo_Studio_V2 2>/dev/null > "$RUN_DIR/workspace_du.txt" || true
fi

for file in \
  /workspace/logs/comfyui.log \
  /workspace/logs/neo_studio.log \
  /workspace/logs/koboldcpp.log \
  /workspace/logs/model_downloader.log \
  /workspace/logs/healthcheck.tsv \
  /workspace/logs/healthcheck_summary.env \
  /workspace/logs/koboldcpp_status.env \
  /workspace/logs/koboldcpp_runtime_status.env \
  /workspace/logs/koboldcpp_check.tsv \
  /workspace/logs/koboldcpp_check_summary.env; do
  if [[ -f "$file" ]]; then
    tail -n 400 "$file" > "$RUN_DIR/$(basename "$file").tail" 2>&1 || true
  fi
done

if [[ -d "${NEO_ROOT:-/workspace/Neo_Studio_V2}/neo_data/logs/image" ]]; then
  find "${NEO_ROOT:-/workspace/Neo_Studio_V2}/neo_data/logs/image" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS\t%p\n' 2>/dev/null | sort | tail -n 80 > "$RUN_DIR/neo_image_log_index.tsv" || true
  latest_error="${NEO_ROOT:-/workspace/Neo_Studio_V2}/neo_data/logs/image/neo_client_generation_error_latest.json"
  if [[ -f "$latest_error" ]]; then
    python -m json.tool "$latest_error" > "$RUN_DIR/neo_client_generation_error_latest.pretty.json" 2>/dev/null || cp "$latest_error" "$RUN_DIR/neo_client_generation_error_latest.json"
  fi
fi

if [[ -x /opt/neo-runpod/scripts/kobold_lane_report.sh ]]; then
  KOBOLD_LANE_REPORT_MD="$RUN_DIR/kobold_lane_report.md" KOBOLD_LANE_REPORT_TSV="$RUN_DIR/kobold_lane_report.tsv" /opt/neo-runpod/scripts/kobold_lane_report.sh > "$RUN_DIR/kobold_lane_report.log" 2>&1 || true
fi

cat > "$RUN_DIR/README.md" <<EOF
# Runtime diagnostics snapshot

Created: $TS

## Key files

- service_http.tsv — HTTP health probe status codes
- nvidia_smi.txt / nvidia_smi_query.csv — GPU state
- comfyui.log.tail — recent Comfy log
- neo_studio.log.tail — recent Neo log
- kobold_lane_report.md — Kobold binary/model/API diagnosis
- neo_image_log_index.tsv — latest Neo image diagnostic files, if present

## For Neo-vs-Comfy speed debugging

1. Run a direct Comfy generation and note Comfy's own elapsed time.
2. Run the same generation through Neo.
3. Compare `comfyui.log.tail`, `neo_studio.log.tail`, and GPU usage.
4. If Comfy finishes fast but Neo UI finishes late, the delay is in Neo polling/output handling.
5. If Comfy itself runs longer, Neo is submitting a heavier or different workflow/params.

For live sampling during one generation, run:

```bash
/opt/neo-runpod/scripts/trace_generation_timing.sh 240
```
EOF

ln -sfn "$RUN_DIR" "$OUT_DIR/latest"
log "Done: $RUN_DIR"
