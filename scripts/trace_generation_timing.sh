#!/usr/bin/env bash
set -Eeuo pipefail

DURATION_SECONDS="${1:-${TRACE_DURATION_SECONDS:-240}}"
INTERVAL_SECONDS="${TRACE_INTERVAL_SECONDS:-1}"
OUT_DIR="${TRACE_OUTPUT_DIR:-/workspace/logs/generation_traces/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$OUT_DIR"

log() {
  printf '[trace-generation] %s\n' "$*"
}

log "Trace directory: $OUT_DIR"
log "Duration: ${DURATION_SECONDS}s / interval: ${INTERVAL_SECONDS}s"
log "Start this script, then trigger one Neo generation and one direct Comfy generation for comparison."

cat > "$OUT_DIR/trace_metadata.env" <<EOF
TRACE_STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TRACE_DURATION_SECONDS=$DURATION_SECONDS
TRACE_INTERVAL_SECONDS=$INTERVAL_SECONDS
NEO_PORT=${NEO_PORT:-7860}
COMFY_PORT=${COMFY_PORT:-8188}
START_KOBOLD=${START_KOBOLD:-0}
KOBOLD_PORT=${KOBOLD_PORT:-5001}
EOF

# Capture a stable before snapshot.
for file in /workspace/logs/comfyui.log /workspace/logs/neo_studio.log /workspace/logs/koboldcpp.log; do
  if [[ -f "$file" ]]; then
    tail -n 120 "$file" > "$OUT_DIR/before_$(basename "$file").tail" 2>&1 || true
  fi
done

if command -v nvidia-smi >/dev/null 2>&1; then
  printf 'timestamp,index,name,utilization.gpu,memory.used,memory.total,power.draw\n' > "$OUT_DIR/gpu_samples.csv"
  end_epoch=$(( $(date +%s) + DURATION_SECONDS ))
  while [[ "$(date +%s)" -le "$end_epoch" ]]; do
    nvidia-smi --query-gpu=timestamp,index,name,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits >> "$OUT_DIR/gpu_samples.csv" 2>> "$OUT_DIR/gpu_samples.err" || true
    sleep "$INTERVAL_SECONDS"
  done
else
  printf 'nvidia-smi not found\n' > "$OUT_DIR/gpu_samples.err"
  sleep "$DURATION_SECONDS"
fi

cat > "$OUT_DIR/service_status.tsv" <<EOF
service\tstatus_code\turl
EOF
probe() {
  local service="$1"
  local url="$2"
  local code="000"
  code="$(curl -sS -o "$OUT_DIR/${service}.body" -w '%{http_code}' --max-time 5 "$url" 2>"$OUT_DIR/${service}.err" || true)"
  printf '%s\t%s\t%s\n' "$service" "$code" "$url" >> "$OUT_DIR/service_status.tsv"
}
probe neo "http://127.0.0.1:${NEO_PORT:-7860}/api/health"
probe comfy "http://127.0.0.1:${COMFY_PORT:-8188}/system_stats"
if [[ "${START_KOBOLD:-0}" == "1" ]]; then
  probe kobold "http://127.0.0.1:${KOBOLD_PORT:-5001}/v1/models"
fi

for file in /workspace/logs/comfyui.log /workspace/logs/neo_studio.log /workspace/logs/koboldcpp.log; do
  if [[ -f "$file" ]]; then
    tail -n 500 "$file" > "$OUT_DIR/after_$(basename "$file").tail" 2>&1 || true
  fi
done

if [[ -d "${NEO_ROOT:-/workspace/Neo_Studio_V2}/neo_data/logs/image" ]]; then
  find "${NEO_ROOT:-/workspace/Neo_Studio_V2}/neo_data/logs/image" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS\t%p\n' 2>/dev/null | sort | tail -n 80 > "$OUT_DIR/neo_image_log_index.tsv" || true
fi

{
  printf '# Generation timing trace\n\n'
  printf 'Started: %s\n' "$(grep '^TRACE_STARTED_AT=' "$OUT_DIR/trace_metadata.env" | cut -d= -f2-)"
  printf 'Duration: %ss\n\n' "$DURATION_SECONDS"
  cat <<'EOF'
## How to read this

- gpu_samples.csv shows GPU utilization and VRAM during the trace window.
- before_comfyui.log.tail and after_comfyui.log.tail show whether Comfy itself spent the extra time.
- before_neo_studio.log.tail and after_neo_studio.log.tail show whether Neo waited after Comfy completed.
- service_status.tsv confirms Neo/Comfy/Kobold readiness at trace end.

## Diagnosis rule

- Comfy log slow + GPU busy = backend workflow/settings/model route is slower.
- Comfy log fast + Neo late = Neo polling/output-copy/metadata side is slower.
- GPU idle while Neo says running = UI/provider state tracking delay.
EOF
} > "$OUT_DIR/README.md"

mkdir -p "${TRACE_OUTPUT_DIR_ROOT:-/workspace/logs/generation_traces}"
ln -sfn "$OUT_DIR" "${TRACE_OUTPUT_DIR_ROOT:-/workspace/logs/generation_traces}/latest" 2>/dev/null || true
log "Done: $OUT_DIR"
