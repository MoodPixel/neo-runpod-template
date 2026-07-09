#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[install-nodes] %s\n' "$*"
}

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
NEO_ROOT="${NEO_ROOT:-/workspace/Neo_Studio_V2}"
CUSTOM_NODES_DIR="${COMFY_CUSTOM_NODES_DIR:-$COMFY_ROOT/custom_nodes}"
MANIFEST="${COMFY_NODE_MANIFEST:-/opt/neo-runpod/config/comfy-node-manifest.tsv}"
STATUS_FILE="${COMFY_NODE_STATUS_FILE:-/workspace/logs/comfy_nodes_status.tsv}"
COMFY_NODE_GROUPS="${COMFY_NODE_GROUPS:-core,image,video,finish}"
INSTALL_CUSTOM_NODE_REQUIREMENTS="${INSTALL_CUSTOM_NODE_REQUIREMENTS:-1}"
RUN_CUSTOM_NODE_INSTALLERS="${RUN_CUSTOM_NODE_INSTALLERS:-0}"
COMFY_NODES_STRICT="${COMFY_NODES_STRICT:-0}"
NEO_SCENE_DIRECTOR_MODE="${NEO_SCENE_DIRECTOR_MODE:-symlink}"

if [[ ! -d "$COMFY_ROOT" ]]; then
  log "ComfyUI root missing at $COMFY_ROOT; skipping custom nodes"
  exit 0
fi

mkdir -p "$CUSTOM_NODES_DIR" /workspace/logs
: > "$STATUS_FILE"
printf 'name\tstatus\tdetail\n' >> "$STATUS_FILE"

record_status() {
  local name="$1"
  local status="$2"
  local detail="${3:-}"
  printf '%s\t%s\t%s\n' "$name" "$status" "$detail" >> "$STATUS_FILE"
}

contains_group() {
  local node_groups=",$1,"
  local enabled=",$COMFY_NODE_GROUPS,"
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

clone_or_update() {
  local name="$1"
  local url="$2"
  local required="${3:-no}"
  local target="$CUSTOM_NODES_DIR/$name"
  local ok=1

  if [[ -d "$target/.git" ]]; then
    if [[ "${AUTO_UPDATE_CUSTOM_NODES:-0}" == "1" ]]; then
      log "Updating $name"
      if git -C "$target" pull --ff-only; then
        record_status "$name" "updated" "$target"
      else
        ok=0
        record_status "$name" "update_failed" "$target"
        log "Warning: update failed for $name"
      fi
    else
      log "$name already exists; leaving untouched"
      record_status "$name" "exists" "$target"
    fi
  elif [[ -e "$target" ]]; then
    log "Warning: $target exists but is not a git repo; leaving untouched"
    record_status "$name" "exists_non_git" "$target"
  else
    log "Cloning $name"
    if git clone --depth 1 "$url" "$target"; then
      record_status "$name" "cloned" "$target"
    else
      ok=0
      record_status "$name" "clone_failed" "$url"
      log "Warning: clone failed for $name"
    fi
  fi

  if [[ -d "$target" && "$INSTALL_CUSTOM_NODE_REQUIREMENTS" == "1" && -f "$target/requirements.txt" ]]; then
    log "Installing requirements for $name"
    if python -m pip install -r "$target/requirements.txt"; then
      record_status "$name" "requirements_ok" "requirements.txt"
    else
      ok=0
      record_status "$name" "requirements_failed" "requirements.txt"
      log "Warning: requirements install failed for $name"
    fi
  fi

  if [[ -d "$target" && -f "$target/install.py" && "$RUN_CUSTOM_NODE_INSTALLERS" == "1" ]]; then
    log "Running install.py for $name"
    if python "$target/install.py"; then
      record_status "$name" "installer_ok" "install.py"
    else
      ok=0
      record_status "$name" "installer_failed" "install.py"
      log "Warning: install.py failed for $name"
    fi
  fi

  if [[ "$required" == "yes" && "$COMFY_NODES_STRICT" == "1" && "$ok" != "1" ]]; then
    log "Strict mode enabled and required node failed: $name"
    return 1
  fi
  return 0
}

install_manifest_nodes() {
  if [[ ! -f "$MANIFEST" ]]; then
    log "Node manifest missing at $MANIFEST; skipping third-party nodes"
    return 0
  fi

  local name url groups required
  while IFS=$'\t' read -r name url groups required; do
    [[ -z "${name// /}" ]] && continue
    [[ "$name" == \#* ]] && continue
    if contains_group "$groups"; then
      clone_or_update "$name" "$url" "${required:-no}" || return 1
    else
      log "Skipping $name; groups '$groups' not enabled by COMFY_NODE_GROUPS=$COMFY_NODE_GROUPS"
      record_status "$name" "skipped_group" "$groups"
    fi
  done < "$MANIFEST"
}

sync_neo_scene_director() {
  if [[ "$NEO_SCENE_DIRECTOR_MODE" == "skip" || "$NEO_SCENE_DIRECTOR_MODE" == "0" ]]; then
    log "NEO_SCENE_DIRECTOR_MODE=$NEO_SCENE_DIRECTOR_MODE; skipping Neo Scene Director sync"
    record_status "neo_scene_director" "skipped" "mode=$NEO_SCENE_DIRECTOR_MODE"
    return 0
  fi

  local candidate target temp
  target="$CUSTOM_NODES_DIR/neo_scene_director"

  for candidate in \
    "$NEO_ROOT/neo_scene_director" \
    "$NEO_ROOT/custom_nodes/neo_scene_director" \
    "$NEO_ROOT/neo_extensions/built_in/neo_scene_director" \
    "$NEO_ROOT/neo_extensions/built_in/image.scene_director/neo_scene_director"; do
    if [[ -f "$candidate/__init__.py" && -f "$candidate/nodes.py" ]]; then
      if [[ -L "$target" && ! -e "$target" ]]; then
        log "Removing broken neo_scene_director symlink at $target"
        rm -f "$target"
      fi

      if [[ "$NEO_SCENE_DIRECTOR_MODE" == "copy" ]]; then
        log "Copying neo_scene_director from $candidate"
        rm -rf "$target"
        cp -a "$candidate" "$target"
        record_status "neo_scene_director" "copied" "$candidate -> $target"
      else
        log "Linking neo_scene_director from $candidate"
        if [[ -e "$target" || -L "$target" ]]; then
          if [[ "$(readlink "$target" 2>/dev/null || true)" == "$candidate" ]]; then
            record_status "neo_scene_director" "linked_exists" "$target -> $candidate"
            return 0
          fi
          if [[ "${AUTO_UPDATE_NEO_SCENE_DIRECTOR_LINK:-1}" == "1" ]]; then
            rm -rf "$target"
          else
            log "neo_scene_director target exists and AUTO_UPDATE_NEO_SCENE_DIRECTOR_LINK=0; leaving untouched"
            record_status "neo_scene_director" "exists" "$target"
            return 0
          fi
        fi
        temp="$CUSTOM_NODES_DIR/.neo_scene_director.tmp"
        rm -f "$temp"
        ln -s "$candidate" "$temp"
        mv -Tf "$temp" "$target"
        record_status "neo_scene_director" "linked" "$target -> $candidate"
      fi
      return 0
    fi
  done

  log "Warning: neo_scene_director source not found under $NEO_ROOT"
  record_status "neo_scene_director" "missing" "$NEO_ROOT"
  if [[ "$COMFY_NODES_STRICT" == "1" ]]; then
    return 1
  fi
  return 0
}

install_manifest_nodes
sync_neo_scene_director

log "Custom node install step complete"
log "Node status: $STATUS_FILE"
