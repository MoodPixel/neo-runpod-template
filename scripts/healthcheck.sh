#!/usr/bin/env bash
set -Eeuo pipefail

NEO_PORT="${NEO_PORT:-7860}"
COMFY_PORT="${COMFY_PORT:-8188}"
KOBOLD_PORT="${KOBOLD_PORT:-5001}"

ok=1

check() {
  local name="$1"
  local url="$2"
  if curl -fsS --max-time 5 "$url" >/dev/null; then
    printf '[healthcheck] %s ok: %s\n' "$name" "$url"
  else
    printf '[healthcheck] %s not ready: %s\n' "$name" "$url"
    ok=0
  fi
}

if [[ "${START_NEO:-1}" == "1" ]]; then
  check "neo" "http://127.0.0.1:${NEO_PORT}/api/health"
fi

if [[ "${START_COMFY:-1}" == "1" ]]; then
  check "comfy" "http://127.0.0.1:${COMFY_PORT}/system_stats"
fi

if [[ "${START_KOBOLD:-0}" == "1" ]]; then
  check "koboldcpp" "http://127.0.0.1:${KOBOLD_PORT}/v1/models"
fi

exit "$ok"
