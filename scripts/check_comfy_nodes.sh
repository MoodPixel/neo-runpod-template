#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[check-nodes] %s\n' "$*"
}

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
CUSTOM_NODES_DIR="${COMFY_CUSTOM_NODES_DIR:-$COMFY_ROOT/custom_nodes}"
MANIFEST="${COMFY_NODE_MANIFEST:-/opt/neo-runpod/config/comfy-node-manifest.tsv}"
COMFY_NODE_GROUPS="${COMFY_NODE_GROUPS:-core,image,video,finish}"
COMFY_NODES_STRICT="${COMFY_NODES_STRICT:-0}"
REPORT_FILE="${COMFY_NODE_CHECK_REPORT:-/workspace/logs/comfy_nodes_check.tsv}"

mkdir -p /workspace/logs
: > "$REPORT_FILE"
printf 'name\tstatus\tdetail\n' >> "$REPORT_FILE"

record() {
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$REPORT_FILE"
}

contains_group() {
  local node_groups=",$1,"
  local group
  IFS=',' read -ra enabled_groups <<< "$COMFY_NODE_GROUPS"
  for group in "${enabled_groups[@]}"; do
    group="${group// /}"
    if [[ -n "$group" && "$node_groups" == *",$group,"* ]]; then
      return 0
    fi
  done
  return 1
}

missing=0

if [[ ! -d "$CUSTOM_NODES_DIR" ]]; then
  log "custom_nodes directory missing: $CUSTOM_NODES_DIR"
  record "custom_nodes" "missing" "$CUSTOM_NODES_DIR"
  exit 1
fi

if [[ -f "$MANIFEST" ]]; then
  while IFS=$'\t' read -r name url groups required; do
    [[ -z "${name// /}" ]] && continue
    [[ "$name" == \#* ]] && continue
    if ! contains_group "$groups"; then
      record "$name" "skipped_group" "$groups"
      continue
    fi
    if [[ -d "$CUSTOM_NODES_DIR/$name" ]]; then
      record "$name" "present" "$CUSTOM_NODES_DIR/$name"
    else
      record "$name" "missing" "$CUSTOM_NODES_DIR/$name"
      if [[ "${required:-no}" == "yes" ]]; then
        missing=$((missing + 1))
      fi
    fi
  done < "$MANIFEST"
else
  record "manifest" "missing" "$MANIFEST"
fi

if [[ -f "$CUSTOM_NODES_DIR/neo_scene_director/__init__.py" && -f "$CUSTOM_NODES_DIR/neo_scene_director/nodes.py" ]]; then
  record "neo_scene_director" "present" "$CUSTOM_NODES_DIR/neo_scene_director"
else
  record "neo_scene_director" "missing" "$CUSTOM_NODES_DIR/neo_scene_director"
  missing=$((missing + 1))
fi

log "Node check report: $REPORT_FILE"
if [[ "$missing" -gt 0 ]]; then
  log "Missing required node count: $missing"
  if [[ "$COMFY_NODES_STRICT" == "1" ]]; then
    exit 1
  fi
fi

exit 0
