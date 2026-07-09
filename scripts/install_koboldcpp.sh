#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[install-koboldcpp] %s\n' "$*"
}

KOBOLDCPP_ROOT="${KOBOLDCPP_ROOT:-/workspace/koboldcpp}"
KOBOLDCPP_BIN="${KOBOLDCPP_BIN:-$KOBOLDCPP_ROOT/koboldcpp-linux-x64}"
KOBOLDCPP_URL="${KOBOLDCPP_URL:-}"
KOBOLDCPP_SHA256="${KOBOLDCPP_SHA256:-}"
KOBOLDCPP_STATUS_FILE="${KOBOLDCPP_STATUS_FILE:-/workspace/logs/koboldcpp_status.env}"
KOBOLD_MODE="${KOBOLD_MODE:-optional}"

mkdir -p "$KOBOLDCPP_ROOT" /workspace/logs /workspace/neo-models/text

write_status() {
  local state="$1"
  local detail="${2:-}"
  cat > "$KOBOLDCPP_STATUS_FILE" <<EOF
KOBOLDCPP_STATE=$state
KOBOLDCPP_BIN=$KOBOLDCPP_BIN
KOBOLDCPP_ROOT=$KOBOLDCPP_ROOT
KOBOLD_MODEL=${KOBOLD_MODEL:-/workspace/neo-models/text/model.gguf}
KOBOLDCPP_DETAIL=$detail
EOF
  log "Status written: $KOBOLDCPP_STATUS_FILE"
}

if [[ "${START_KOBOLD:-0}" != "1" && "${INSTALL_KOBOLD:-0}" != "1" ]]; then
  log "START_KOBOLD=0 and INSTALL_KOBOLD=0, skipping KoboldCPP install"
  write_status "disabled" "START_KOBOLD=0 INSTALL_KOBOLD=0"
  exit 0
fi

if [[ -x "$KOBOLDCPP_BIN" ]]; then
  log "KoboldCPP binary already exists at $KOBOLDCPP_BIN"
  write_status "ready" "existing executable"
  exit 0
fi

if [[ -f "$KOBOLDCPP_BIN" && ! -x "$KOBOLDCPP_BIN" ]]; then
  log "KoboldCPP binary exists but is not executable; fixing chmod"
  chmod +x "$KOBOLDCPP_BIN" || true
  if [[ -x "$KOBOLDCPP_BIN" ]]; then
    write_status "ready" "chmod fixed"
    exit 0
  fi
fi

if [[ -z "$KOBOLDCPP_URL" ]]; then
  log "KOBOLDCPP_URL is empty; mount/download a binary to $KOBOLDCPP_BIN or set KOBOLDCPP_URL."
  write_status "missing_binary" "KOBOLDCPP_URL empty"
  if [[ "$KOBOLD_MODE" == "required" || "${KOBOLD_STRICT:-0}" == "1" ]]; then
    exit 1
  fi
  exit 0
fi

log "Downloading KoboldCPP binary from KOBOLDCPP_URL"
tmp="$KOBOLDCPP_BIN.download"
rm -f "$tmp"

if command -v curl >/dev/null 2>&1; then
  curl -fL --retry 3 --retry-delay 3 -o "$tmp" "$KOBOLDCPP_URL"
else
  wget -O "$tmp" "$KOBOLDCPP_URL"
fi

if [[ -n "$KOBOLDCPP_SHA256" ]]; then
  log "Verifying KOBOLDCPP_SHA256"
  printf '%s  %s\n' "$KOBOLDCPP_SHA256" "$tmp" | sha256sum -c -
fi

mv "$tmp" "$KOBOLDCPP_BIN"
chmod +x "$KOBOLDCPP_BIN"
write_status "ready" "downloaded"
log "KoboldCPP install step complete"
