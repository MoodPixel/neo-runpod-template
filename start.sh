#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[neo-runpod] %s\n' "$*"
}

export NEO_ROOT="${NEO_ROOT:-/workspace/Neo_Studio_V2}"
export COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
export MODEL_ROOT="${MODEL_ROOT:-/workspace/neo-models}"
export KOBOLDCPP_ROOT="${KOBOLDCPP_ROOT:-/workspace/koboldcpp}"

export NEO_HOST="${NEO_HOST:-0.0.0.0}"
export NEO_PORT="${NEO_PORT:-7860}"
export COMFY_HOST="${COMFY_HOST:-0.0.0.0}"
export COMFY_PORT="${COMFY_PORT:-8188}"
export KOBOLD_HOST="${KOBOLD_HOST:-0.0.0.0}"
export KOBOLD_PORT="${KOBOLD_PORT:-5001}"

export NEO_COMFY_BASE_URL="${NEO_COMFY_BASE_URL:-http://127.0.0.1:${COMFY_PORT}}"
export NEO_KOBOLD_BASE_URL="${NEO_KOBOLD_BASE_URL:-http://127.0.0.1:${KOBOLD_PORT}}"

mkdir -p \
  /workspace \
  "$MODEL_ROOT" \
  "$KOBOLDCPP_ROOT" \
  /workspace/logs \
  /workspace/tmp

log "Neo RunPod template starting"
log "Neo root:       $NEO_ROOT"
log "Comfy root:     $COMFY_ROOT"
log "Model root:     $MODEL_ROOT"
log "Profile:        ${MODEL_PROFILE:-none}"
log "Comfy URL:      $NEO_COMFY_BASE_URL"
log "Kobold URL:     $NEO_KOBOLD_BASE_URL"
log "Comfy nodes:    ${COMFY_NODE_GROUPS:-core,image,video,finish}"
log "Scene Director: ${NEO_SCENE_DIRECTOR_MODE:-symlink}"

if [[ "${INSTALL_COMFY:-1}" != "0" ]]; then
  /opt/neo-runpod/scripts/install_comfy.sh
else
  log "INSTALL_COMFY=0, skipping ComfyUI install/update"
fi

if [[ "${INSTALL_NEO:-1}" != "0" ]]; then
  /opt/neo-runpod/scripts/install_neo.sh
else
  log "INSTALL_NEO=0, skipping Neo Studio install/update"
fi

if [[ "${INSTALL_CUSTOM_NODES:-1}" != "0" ]]; then
  /opt/neo-runpod/scripts/install_custom_nodes.sh
else
  log "INSTALL_CUSTOM_NODES=0, skipping custom node install/update"
fi

/opt/neo-runpod/scripts/install_koboldcpp.sh

if [[ "${MODEL_PROFILE:-none}" != "skip" ]]; then
  log "Preparing model folders / downloads via neo_download_models.py"
  python /opt/neo-runpod/neo_download_models.py
else
  log "MODEL_PROFILE=skip, skipping model helper entirely"
fi

if [[ -f /opt/neo-runpod/scripts/patch_neo_profiles.py && "${NEO_PATCH_PROFILES:-1}" != "0" ]]; then
  log "Applying optional Neo backend profile patch"
  python /opt/neo-runpod/scripts/patch_neo_profiles.py || log "Profile patch failed; continuing so services can expose diagnostics"
fi

exec /opt/neo-runpod/scripts/start_services.sh
