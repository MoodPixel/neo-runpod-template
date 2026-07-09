#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[install-nodes] %s\n' "$*"
}

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
NEO_ROOT="${NEO_ROOT:-/workspace/Neo_Studio_V2}"
CUSTOM_NODES_DIR="$COMFY_ROOT/custom_nodes"

if [[ ! -d "$COMFY_ROOT" ]]; then
  log "ComfyUI root missing at $COMFY_ROOT; skipping custom nodes"
  exit 0
fi

mkdir -p "$CUSTOM_NODES_DIR"

clone_or_update() {
  local name="$1"
  local url="$2"
  local target="$CUSTOM_NODES_DIR/$name"

  if [[ -d "$target/.git" ]]; then
    if [[ "${AUTO_UPDATE_CUSTOM_NODES:-0}" == "1" ]]; then
      log "Updating $name"
      git -C "$target" pull --ff-only || log "Warning: update failed for $name"
    else
      log "$name already exists; leaving untouched"
    fi
  elif [[ -e "$target" ]]; then
    log "Warning: $target exists but is not a git repo; leaving untouched"
  else
    log "Cloning $name"
    git clone --depth 1 "$url" "$target" || log "Warning: clone failed for $name"
  fi

  if [[ -f "$target/requirements.txt" ]]; then
    log "Installing requirements for $name"
    python -m pip install -r "$target/requirements.txt" || log "Warning: requirements install failed for $name"
  fi

  if [[ -f "$target/install.py" && "${RUN_CUSTOM_NODE_INSTALLERS:-0}" == "1" ]]; then
    log "Running install.py for $name"
    python "$target/install.py" || log "Warning: install.py failed for $name"
  fi
}

# Recommended Neo image/video node base. Keep failures non-fatal so a broken external
# node repo does not prevent Neo Studio from starting and showing diagnostics.
clone_or_update "comfyui-essentials" "https://github.com/comfyorg/comfyui-essentials.git"
clone_or_update "ComfyUI-GGUF" "https://github.com/city96/ComfyUI-GGUF.git"
clone_or_update "gguf" "https://github.com/calcuis/gguf.git"
clone_or_update "ComfyUI-Impact-Pack" "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
clone_or_update "ComfyUI-Impact-Subpack" "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git"
clone_or_update "ComfyUI-Inspire-Pack" "https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git"
clone_or_update "ComfyUI-KJNodes" "https://github.com/kijai/ComfyUI-KJNodes.git"
clone_or_update "comfyui_controlnet_aux" "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
clone_or_update "ComfyUI_IPAdapter_plus" "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
clone_or_update "ComfyUI_UltimateSDUpscale" "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
clone_or_update "sd-dynamic-thresholding" "https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git"
clone_or_update "RES4LYF" "https://github.com/ClownsharkBatwing/RES4LYF.git"
clone_or_update "rgthree-comfy" "https://github.com/rgthree/rgthree-comfy.git"
clone_or_update "facerestore_cf" "https://github.com/mav-rik/facerestore_cf.git"
clone_or_update "ComfyUI-WanVideoWrapper" "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
clone_or_update "ComfyUI-TeaCache" "https://github.com/welltop-cn/ComfyUI-TeaCache.git"
clone_or_update "ComfyUI-LTXVideo" "https://github.com/Lightricks/ComfyUI-LTXVideo.git"
clone_or_update "ComfyUI-Frame-Interpolation" "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
clone_or_update "ComfyUI-VideoHelperSuite" "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
clone_or_update "ComfyUI-SeedVR2_VideoUpscaler" "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"

# Neo-owned Scene Director node support, when the public Neo checkout contains it.
for candidate in \
  "$NEO_ROOT/neo_scene_director" \
  "$NEO_ROOT/custom_nodes/neo_scene_director" \
  "$NEO_ROOT/neo_extensions/built_in/neo_scene_director" \
  "$NEO_ROOT/neo_extensions/built_in/image.scene_director/neo_scene_director"; do
  if [[ -d "$candidate" ]]; then
    target="$CUSTOM_NODES_DIR/neo_scene_director"
    if [[ ! -e "$target" ]]; then
      log "Linking neo_scene_director from $candidate"
      ln -s "$candidate" "$target" || cp -R "$candidate" "$target"
    else
      log "neo_scene_director already exists; leaving untouched"
    fi
    break
  fi
done

log "Custom node install step complete"
