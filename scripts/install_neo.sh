#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[install-neo] %s\n' "$*"
}

NEO_ROOT="${NEO_ROOT:-/workspace/Neo_Studio_V2}"
NEO_REPO="${NEO_REPO:-https://github.com/MoodPixel/Neo_Studio_V2.git}"
NEO_BRANCH="${NEO_BRANCH:-main}"

mkdir -p "$(dirname "$NEO_ROOT")"

if [[ ! -d "$NEO_ROOT/.git" ]]; then
  log "Cloning Neo Studio into $NEO_ROOT"
  git clone --depth 1 --branch "$NEO_BRANCH" "$NEO_REPO" "$NEO_ROOT"
elif [[ "${AUTO_UPDATE_NEO:-0}" == "1" ]]; then
  log "Updating Neo Studio with git pull --ff-only"
  git -C "$NEO_ROOT" pull --ff-only
else
  log "Neo Studio already exists; AUTO_UPDATE_NEO=0 so leaving checkout untouched"
fi

if [[ -f "$NEO_ROOT/requirements.txt" ]]; then
  log "Installing Neo core requirements"
  python -m pip install -r "$NEO_ROOT/requirements.txt"
else
  log "No Neo requirements.txt found; skipping core requirements"
fi

if [[ "${INSTALL_NEO_MEMORY:-1}" != "0" && -f "$NEO_ROOT/requirements-memory.txt" ]]; then
  log "Installing Neo memory / semantic requirements"
  python -m pip install -r "$NEO_ROOT/requirements-memory.txt"
elif [[ "${INSTALL_NEO_MEMORY:-1}" == "0" ]]; then
  log "INSTALL_NEO_MEMORY=0, skipping memory requirements"
else
  log "No requirements-memory.txt found; skipping memory requirements"
fi

mkdir -p "$NEO_ROOT/neo_data" /workspace/logs
log "Neo Studio install step complete"
