#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[install-comfy] %s\n' "$*"
}

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
COMFY_REPO="${COMFY_REPO:-https://github.com/Comfy-Org/ComfyUI.git}"
COMFY_BRANCH="${COMFY_BRANCH:-master}"

mkdir -p "$(dirname "$COMFY_ROOT")"

if [[ ! -d "$COMFY_ROOT/.git" ]]; then
  log "Cloning ComfyUI into $COMFY_ROOT"
  git clone --depth 1 --branch "$COMFY_BRANCH" "$COMFY_REPO" "$COMFY_ROOT"
elif [[ "${AUTO_UPDATE_COMFY:-0}" == "1" ]]; then
  log "Updating ComfyUI with git pull --ff-only"
  git -C "$COMFY_ROOT" pull --ff-only
else
  log "ComfyUI already exists; AUTO_UPDATE_COMFY=0 so leaving checkout untouched"
fi

if [[ -f "$COMFY_ROOT/requirements.txt" ]]; then
  log "Installing ComfyUI requirements"
  python -m pip install -r "$COMFY_ROOT/requirements.txt"
else
  log "No ComfyUI requirements.txt found; skipping pip install"
fi

mkdir -p "$COMFY_ROOT/models" "$COMFY_ROOT/custom_nodes" /workspace/logs
log "ComfyUI install step complete"
