#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[install-koboldcpp] %s\n' "$*"
}

KOBOLDCPP_ROOT="${KOBOLDCPP_ROOT:-/workspace/koboldcpp}"
KOBOLDCPP_BIN="${KOBOLDCPP_BIN:-$KOBOLDCPP_ROOT/koboldcpp-linux-x64}"
KOBOLDCPP_URL="${KOBOLDCPP_URL:-}"

mkdir -p "$KOBOLDCPP_ROOT" /workspace/logs

if [[ "${START_KOBOLD:-0}" != "1" && "${INSTALL_KOBOLD:-0}" != "1" ]]; then
  log "START_KOBOLD=0 and INSTALL_KOBOLD=0, skipping KoboldCPP install"
  exit 0
fi

if [[ -x "$KOBOLDCPP_BIN" ]]; then
  log "KoboldCPP binary already exists at $KOBOLDCPP_BIN"
  exit 0
fi

if [[ -z "$KOBOLDCPP_URL" ]]; then
  log "KOBOLDCPP_URL is empty; skipping binary download. Set KOBOLDCPP_URL or mount a binary at $KOBOLDCPP_BIN."
  exit 0
fi

log "Downloading KoboldCPP binary from KOBOLDCPP_URL"
wget -O "$KOBOLDCPP_BIN" "$KOBOLDCPP_URL"
chmod +x "$KOBOLDCPP_BIN"
log "KoboldCPP install step complete"
