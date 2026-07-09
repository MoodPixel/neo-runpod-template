#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[services] %s\n' "$*"
}

NEO_ROOT="${NEO_ROOT:-/workspace/Neo_Studio_V2}"
COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
KOBOLDCPP_ROOT="${KOBOLDCPP_ROOT:-/workspace/koboldcpp}"
KOBOLDCPP_BIN="${KOBOLDCPP_BIN:-$KOBOLDCPP_ROOT/koboldcpp-linux-x64}"
KOBOLD_MODEL="${KOBOLD_MODEL:-/workspace/neo-models/text/model.gguf}"
KOBOLD_STATUS_FILE="${KOBOLD_STATUS_FILE:-/workspace/logs/koboldcpp_runtime_status.env}"

NEO_HOST="${NEO_HOST:-0.0.0.0}"
NEO_PORT="${NEO_PORT:-7860}"
COMFY_HOST="${COMFY_HOST:-0.0.0.0}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFY_PREVIEW_METHOD="${COMFY_PREVIEW_METHOD:-auto}"
KOBOLD_HOST="${KOBOLD_HOST:-0.0.0.0}"
KOBOLD_PORT="${KOBOLD_PORT:-5001}"
KOBOLD_MODE="${KOBOLD_MODE:-optional}"

mkdir -p /workspace/logs /workspace/neo-models/text

pids=()

write_kobold_status() {
  local state="$1"
  local detail="${2:-}"
  cat > "$KOBOLD_STATUS_FILE" <<EOF
KOBOLD_RUNTIME_STATE=$state
KOBOLD_RUNTIME_DETAIL=$detail
KOBOLD_HOST=$KOBOLD_HOST
KOBOLD_PORT=$KOBOLD_PORT
KOBOLDCPP_BIN=$KOBOLDCPP_BIN
KOBOLD_MODEL=$KOBOLD_MODEL
KOBOLD_MODE=$KOBOLD_MODE
START_KOBOLD=${START_KOBOLD:-0}
EOF
}

maybe_fail_required_kobold() {
  local detail="$1"
  if [[ "$KOBOLD_MODE" == "required" || "${KOBOLD_STRICT:-0}" == "1" ]]; then
    log "KoboldCPP is required but unavailable: $detail"
    return 1
  fi
  return 0
}

start_comfy() {
  if [[ "${START_COMFY:-1}" != "1" ]]; then
    log "START_COMFY=0, skipping ComfyUI"
    return
  fi
  if [[ ! -f "$COMFY_ROOT/main.py" ]]; then
    log "ComfyUI main.py missing at $COMFY_ROOT/main.py; skipping ComfyUI"
    return
  fi

  log "Starting ComfyUI on ${COMFY_HOST}:${COMFY_PORT}"
  (
    cd "$COMFY_ROOT"
    python main.py \
      --listen "$COMFY_HOST" \
      --port "$COMFY_PORT" \
      --preview-method "$COMFY_PREVIEW_METHOD" \
      ${COMFY_EXTRA_ARGS:-}
  ) > /workspace/logs/comfyui.log 2>&1 &
  pids+=("$!")
}

start_kobold() {
  if [[ "${START_KOBOLD:-0}" != "1" ]]; then
    log "START_KOBOLD=0, skipping KoboldCPP"
    write_kobold_status "disabled" "START_KOBOLD=0"
    return
  fi
  if [[ ! -x "$KOBOLDCPP_BIN" ]]; then
    log "KoboldCPP binary missing or not executable at $KOBOLDCPP_BIN; skipping KoboldCPP"
    write_kobold_status "missing_binary" "$KOBOLDCPP_BIN"
    maybe_fail_required_kobold "missing binary" || return 1
    return
  fi
  if [[ ! -f "$KOBOLD_MODEL" ]]; then
    log "Kobold model missing at $KOBOLD_MODEL; skipping KoboldCPP"
    write_kobold_status "missing_model" "$KOBOLD_MODEL"
    maybe_fail_required_kobold "missing model" || return 1
    return
  fi

  write_kobold_status "starting" "launching"
  log "Starting KoboldCPP on ${KOBOLD_HOST}:${KOBOLD_PORT} with model $KOBOLD_MODEL"
  "$KOBOLDCPP_BIN" \
    --model "$KOBOLD_MODEL" \
    --host "$KOBOLD_HOST" \
    --port "$KOBOLD_PORT" \
    ${KOBOLD_EXTRA_ARGS:-${KOBOLDCPP_EXTRA_ARGS:-}} \
    > /workspace/logs/koboldcpp.log 2>&1 &
  pids+=("$!")
  write_kobold_status "started" "pid=${pids[-1]}"
}

start_neo() {
  if [[ "${START_NEO:-1}" != "1" ]]; then
    log "START_NEO=0, skipping Neo Studio"
    return
  fi
  if [[ ! -d "$NEO_ROOT/neo_app" ]]; then
    log "Neo app package missing at $NEO_ROOT/neo_app; cannot start Neo"
    return
  fi

  export NEO_HOST="$NEO_HOST"
  export NEO_PORT="$NEO_PORT"
  export NEO_BACKEND_BASE_URL="${NEO_BACKEND_BASE_URL:-http://127.0.0.1:${KOBOLD_PORT}}"

  log "Starting Neo Studio on ${NEO_HOST}:${NEO_PORT}"
  (
    cd "$NEO_ROOT"
    python -m neo_app.main \
      --host "$NEO_HOST" \
      --port "$NEO_PORT" \
      ${NEO_EXTRA_ARGS:-}
  ) > /workspace/logs/neo_studio.log 2>&1 &
  pids+=("$!")
}

shutdown() {
  log "Shutdown requested; stopping services"
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait || true
}
trap shutdown SIGINT SIGTERM

start_comfy
start_kobold
start_neo

if [[ "${#pids[@]}" -eq 0 ]]; then
  log "No services started. Check START_NEO / START_COMFY / START_KOBOLD and install logs."
  exit 1
fi

log "Service logs: /workspace/logs"
touch /workspace/logs/comfyui.log /workspace/logs/koboldcpp.log /workspace/logs/neo_studio.log

tail -n +1 -F /workspace/logs/comfyui.log /workspace/logs/koboldcpp.log /workspace/logs/neo_studio.log &
tail_pid="$!"

# Exit when the first managed service exits. This makes RunPod show a failed pod
# instead of hiding a dead Neo/Comfy process behind a still-running tail.
set +e
wait -n "${pids[@]}"
status="$?"
set -e
kill "$tail_pid" 2>/dev/null || true
shutdown
exit "$status"
