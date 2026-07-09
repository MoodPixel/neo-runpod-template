#!/usr/bin/env bash
set -Eeuo pipefail

NEO_PORT="${NEO_PORT:-7860}"
COMFY_PORT="${COMFY_PORT:-8188}"
KOBOLD_PORT="${KOBOLD_PORT:-5001}"
HEALTHCHECK_TIMEOUT="${HEALTHCHECK_TIMEOUT:-5}"
HEALTH_REPORT_FILE="${HEALTH_REPORT_FILE:-/workspace/logs/healthcheck.tsv}"
HEALTH_SUMMARY_FILE="${HEALTH_SUMMARY_FILE:-/workspace/logs/healthcheck_summary.env}"
HEALTHCHECK_STRICT="${HEALTHCHECK_STRICT:-0}"

mkdir -p /workspace/logs
: > "$HEALTH_REPORT_FILE"
printf 'service\tcheck\tstatus\tseverity\tdetail\n' >> "$HEALTH_REPORT_FILE"

status=0
warnings=0
failures=0

record() {
  local service="$1"
  local check_name="$2"
  local check_status="$3"
  local severity="$4"
  local detail="${5:-}"
  printf '%s\t%s\t%s\t%s\t%s\n' "$service" "$check_name" "$check_status" "$severity" "$detail" >> "$HEALTH_REPORT_FILE"
}

mark_failure() {
  failures=$((failures + 1))
  status=1
}

mark_warning() {
  warnings=$((warnings + 1))
  if [[ "$HEALTHCHECK_STRICT" == "1" ]]; then
    status=1
  fi
}

check_http() {
  local service="$1"
  local check_name="$2"
  local url="$3"
  local severity="${4:-required}"

  if curl -fsS --max-time "$HEALTHCHECK_TIMEOUT" "$url" >/dev/null; then
    printf '[healthcheck] %s %s ok: %s\n' "$service" "$check_name" "$url"
    record "$service" "$check_name" "ok" "$severity" "$url"
    return 0
  fi

  printf '[healthcheck] %s %s not ready: %s\n' "$service" "$check_name" "$url"
  record "$service" "$check_name" "not_ready" "$severity" "$url"

  if [[ "$severity" == "required" ]]; then
    mark_failure
  else
    mark_warning
  fi
  return 1
}

check_file() {
  local service="$1"
  local check_name="$2"
  local path="$3"
  local severity="${4:-required}"

  if [[ -e "$path" ]]; then
    printf '[healthcheck] %s %s ok: %s\n' "$service" "$check_name" "$path"
    record "$service" "$check_name" "ok" "$severity" "$path"
    return 0
  fi

  printf '[healthcheck] %s %s missing: %s\n' "$service" "$check_name" "$path"
  record "$service" "$check_name" "missing" "$severity" "$path"
  if [[ "$severity" == "required" ]]; then
    mark_failure
  else
    mark_warning
  fi
  return 1
}

# Neo Studio is the primary UI/control service.
if [[ "${START_NEO:-1}" == "1" ]]; then
  check_http "neo" "api_health" "http://127.0.0.1:${NEO_PORT}/api/health" "required" || true
else
  record "neo" "api_health" "skipped" "optional" "START_NEO=0"
fi

# ComfyUI is the required image/video backend when enabled.
if [[ "${START_COMFY:-1}" == "1" ]]; then
  check_http "comfy" "system_stats" "http://127.0.0.1:${COMFY_PORT}/system_stats" "required" || true
  if [[ "${CHECK_COMFY_OBJECT_INFO:-0}" == "1" ]]; then
    check_http "comfy" "object_info" "http://127.0.0.1:${COMFY_PORT}/object_info" "optional" || true
  fi
else
  record "comfy" "system_stats" "skipped" "optional" "START_COMFY=0"
fi

# KoboldCPP is optional unless the user marks it required/strict.
if [[ "${START_KOBOLD:-0}" == "1" ]]; then
  kobold_severity="optional"
  if [[ "${KOBOLD_MODE:-optional}" == "required" || "${KOBOLD_STRICT:-0}" == "1" ]]; then
    kobold_severity="required"
  fi

  if [[ "${CHECK_KOBOLDCPP_LANE:-1}" == "1" && -x /opt/neo-runpod/scripts/check_koboldcpp.sh ]]; then
    if /opt/neo-runpod/scripts/check_koboldcpp.sh; then
      printf '[healthcheck] koboldcpp lane check ok\n'
      record "koboldcpp" "lane_check" "ok" "$kobold_severity" "/workspace/logs/koboldcpp_check.tsv"
    else
      printf '[healthcheck] koboldcpp lane check failed\n'
      record "koboldcpp" "lane_check" "failed" "$kobold_severity" "/workspace/logs/koboldcpp_check.tsv"
      if [[ "$kobold_severity" == "required" ]]; then
        mark_failure
      else
        mark_warning
      fi
    fi
  else
    check_http "koboldcpp" "models" "http://127.0.0.1:${KOBOLD_PORT}/v1/models" "$kobold_severity" || true
  fi
else
  record "koboldcpp" "lane_check" "skipped" "optional" "START_KOBOLD=0"
fi

# Optional Comfy custom-node validation. Missing nodes fail only when checker/strict mode says so.
if [[ "${CHECK_COMFY_NODES:-0}" == "1" && -x /opt/neo-runpod/scripts/check_comfy_nodes.sh ]]; then
  node_severity="optional"
  if [[ "${COMFY_NODES_STRICT:-0}" == "1" ]]; then
    node_severity="required"
  fi

  if /opt/neo-runpod/scripts/check_comfy_nodes.sh; then
    printf '[healthcheck] comfy node check ok\n'
    record "comfy_nodes" "manifest_check" "ok" "$node_severity" "/workspace/logs/comfy_nodes_check.tsv"
  else
    printf '[healthcheck] comfy node check failed\n'
    record "comfy_nodes" "manifest_check" "failed" "$node_severity" "/workspace/logs/comfy_nodes_check.tsv"
    if [[ "$node_severity" == "required" ]]; then
      mark_failure
    else
      mark_warning
    fi
  fi
else
  record "comfy_nodes" "manifest_check" "skipped" "optional" "CHECK_COMFY_NODES=0"
fi

cat > "$HEALTH_SUMMARY_FILE" <<EOF
HEALTH_STATUS=$status
HEALTH_FAILURES=$failures
HEALTH_WARNINGS=$warnings
HEALTH_REPORT_FILE=$HEALTH_REPORT_FILE
HEALTHCHECK_STRICT=$HEALTHCHECK_STRICT
EOF

printf '[healthcheck] report: %s\n' "$HEALTH_REPORT_FILE"
printf '[healthcheck] summary: %s\n' "$HEALTH_SUMMARY_FILE"
exit "$status"
