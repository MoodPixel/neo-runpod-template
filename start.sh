#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[neo-runpod] %s\n' "$*"
}

export NEO_ROOT="${NEO_ROOT:-/workspace/Neo_Studio_V2}"
export COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
export MODEL_ROOT="${MODEL_ROOT:-/workspace/neo-models}"
export KOBOLDCPP_ROOT="${KOBOLDCPP_ROOT:-/workspace/koboldcpp}"

mkdir -p \
  /workspace \
  "$MODEL_ROOT" \
  "$KOBOLDCPP_ROOT" \
  /workspace/logs \
  /workspace/tmp

log "Neo RunPod template starting"
log "Neo root:    $NEO_ROOT"
log "Comfy root:  $COMFY_ROOT"
log "Model root:  $MODEL_ROOT"
log "Profile:     ${MODEL_PROFILE:-none}"

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
