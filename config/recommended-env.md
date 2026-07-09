# Recommended RunPod environment variables

These values are the baseline for a persistent Neo Studio pod.

```bash
# Neo Studio checkout
NEO_REPO=https://github.com/MoodPixel/Neo_Studio_V2.git
NEO_BRANCH=main
NEO_ROOT=/workspace/Neo_Studio_V2

# ComfyUI checkout
COMFY_REPO=https://github.com/Comfy-Org/ComfyUI.git
COMFY_BRANCH=master
COMFY_ROOT=/workspace/ComfyUI

# Persistent model bank
MODEL_ROOT=/workspace/neo-models
MODEL_PROFILE=none
HF_TOKEN=

# Service toggles
START_NEO=1
START_COMFY=1
START_KOBOLD=0
INSTALL_KOBOLD=0
KOBOLD_MODE=optional
KOBOLD_STRICT=0
INSTALL_CUSTOM_NODES=1
INSTALL_NEO_MEMORY=1

# Runtime backend-profile patching
NEO_PATCH_PROFILES=1
NEO_COMFY_BASE_URL=http://127.0.0.1:8188
NEO_KOBOLD_BASE_URL=http://127.0.0.1:5001
NEO_IMAGE_PROFILE_ID=comfyui_local
NEO_VIDEO_PROFILE_ID=video.comfyui
NEO_TEXT_PROFILE_ID=local_koboldcpp_text

# Comfy custom-node hardening
COMFY_NODE_GROUPS=core,image,video,finish
INSTALL_CUSTOM_NODE_REQUIREMENTS=1
RUN_CUSTOM_NODE_INSTALLERS=0
NEO_SCENE_DIRECTOR_MODE=symlink
CHECK_COMFY_NODES=0
COMFY_NODES_STRICT=0

# Health checks and readiness
HEALTHCHECK_TIMEOUT=5
HEALTHCHECK_STRICT=0
CHECK_COMFY_OBJECT_INFO=0
RUN_STARTUP_HEALTHCHECK=0
HEALTH_WAIT_TIMEOUT_SECONDS=300
HEALTH_WAIT_INTERVAL_SECONDS=5
CHECK_KOBOLDCPP_LANE=1
CHECK_KOBOLD_API_REQUIRED=0

# Update policy. Keep disabled for reproducible pods.
AUTO_UPDATE_NEO=0
AUTO_UPDATE_COMFY=0
AUTO_UPDATE_CUSTOM_NODES=0
AUTO_UPDATE_NEO_SCENE_DIRECTOR_LINK=1

# Exposed app ports
NEO_HOST=0.0.0.0
NEO_PORT=7860
COMFY_HOST=0.0.0.0
COMFY_PORT=8188
COMFY_PREVIEW_METHOD=auto
KOBOLD_HOST=0.0.0.0
KOBOLD_PORT=5001

# Optional KoboldCPP lane
KOBOLDCPP_ROOT=/workspace/koboldcpp
KOBOLDCPP_BIN=/workspace/koboldcpp/koboldcpp-linux-x64
KOBOLDCPP_URL=
KOBOLDCPP_SHA256=
KOBOLD_MODEL=/workspace/neo-models/text/model.gguf
KOBOLD_TIMEOUT_SECONDS=300
KOBOLD_EXTRA_ARGS=
```

## Model profiles

`MODEL_PROFILE=none` is the safe default. It prepares folders without downloading large model files.

Available model profiles are defined in `neo_download_models.py`. Current useful values include:

```bash
MODEL_PROFILE=none
MODEL_PROFILE=image_core
MODEL_PROFILE=video_core
MODEL_PROFILE=rapid_video_core
MODEL_PROFILE=all
```

Use `HF_TOKEN` when a model requires Hugging Face authentication.

## Backend profile patching

`NEO_PATCH_PROFILES=1` is enabled by default. The patcher writes runtime-only files under:

```text
/workspace/Neo_Studio_V2/neo_data/settings/backends
```

It does **not** edit the Neo Studio source checkout.

Default runtime mapping:

```text
image             -> comfyui_local
video             -> video.comfyui
text              -> local_koboldcpp_text
assistant         -> local_koboldcpp_text
prompt_captioning -> local_koboldcpp_text
roleplay          -> local_koboldcpp_text
```

Override URLs when services run elsewhere:

```bash
NEO_COMFY_BASE_URL=http://127.0.0.1:8188
NEO_KOBOLD_BASE_URL=http://127.0.0.1:5001
```

Disable runtime profile patching only for debugging:

```bash
NEO_PATCH_PROFILES=0
```

## Comfy custom-node hardening

Phase C installs Neo's recommended Comfy custom nodes from:

```text
/opt/neo-runpod/config/comfy-node-manifest.tsv
```

Default enabled groups:

```bash
COMFY_NODE_GROUPS=core,image,video,finish
```

Use a smaller set when testing image-only pods:

```bash
COMFY_NODE_GROUPS=core,image
```

Requirement installation is enabled by default:

```bash
INSTALL_CUSTOM_NODE_REQUIREMENTS=1
```

Custom node `install.py` execution is disabled by default because those installers are third-party code:

```bash
RUN_CUSTOM_NODE_INSTALLERS=0
```

Neo's own Scene Director node is synced from the Neo checkout into ComfyUI:

```bash
NEO_SCENE_DIRECTOR_MODE=symlink
```

Other values:

```bash
NEO_SCENE_DIRECTOR_MODE=copy
NEO_SCENE_DIRECTOR_MODE=skip
```

Node audit reports are written under:

```text
/workspace/logs/comfy_nodes_status.tsv
/workspace/logs/comfy_nodes_check.tsv
```

Enable node checks in healthcheck when debugging:

```bash
CHECK_COMFY_NODES=1
```

Make missing required nodes fail the check only when you want strict validation:

```bash
COMFY_NODES_STRICT=1
```

## KoboldCPP optional text lane

Phase D keeps KoboldCPP disabled by default:

```bash
START_KOBOLD=0
```

That means Neo Studio and ComfyUI still boot even when no text model is present. Neo text, assistant, prompt/captioning, and roleplay surfaces will show backend-disconnected diagnostics until a text backend is enabled.

To enable the local text lane, provide both a KoboldCPP executable and a GGUF model:

```bash
START_KOBOLD=1
KOBOLDCPP_BIN=/workspace/koboldcpp/koboldcpp-linux-x64
KOBOLD_MODEL=/workspace/neo-models/text/model.gguf
```

To download a binary during pod startup instead of mounting one:

```bash
INSTALL_KOBOLD=1
KOBOLDCPP_URL=https://example.com/koboldcpp-linux-x64
KOBOLDCPP_SHA256=
```

Use `KOBOLDCPP_SHA256` when you want checksum verification for the downloaded binary.

The lane is optional by default:

```bash
KOBOLD_MODE=optional
KOBOLD_STRICT=0
```

To intentionally fail startup/checks when Kobold is missing:

```bash
KOBOLD_MODE=required
# or
KOBOLD_STRICT=1
```

Pass extra KoboldCPP launch flags through:

```bash
KOBOLD_EXTRA_ARGS="--your-flags-here"
```

Kobold lane reports are written under:

```text
/workspace/logs/koboldcpp_status.env
/workspace/logs/koboldcpp_runtime_status.env
/workspace/logs/koboldcpp_check.tsv
```

## Health checks and readiness

Phase E provides two health layers:

```bash
/opt/neo-runpod/scripts/healthcheck.sh
/opt/neo-runpod/scripts/wait_for_services.sh
```

`healthcheck.sh` checks enabled services and writes:

```text
/workspace/logs/healthcheck.tsv
/workspace/logs/healthcheck_summary.env
```

Default behavior is forgiving:

```bash
HEALTHCHECK_STRICT=0
```

Required by default:

```text
Neo /api/health when START_NEO=1
ComfyUI /system_stats when START_COMFY=1
```

Optional unless strict/required:

```text
KoboldCPP lane
Comfy custom-node manifest check
Comfy /object_info check
```

To run the readiness loop manually:

```bash
/opt/neo-runpod/scripts/wait_for_services.sh
```

Readiness loop controls:

```bash
HEALTH_WAIT_TIMEOUT_SECONDS=300
HEALTH_WAIT_INTERVAL_SECONDS=5
```

To run the readiness loop automatically after services start, enable:

```bash
RUN_STARTUP_HEALTHCHECK=1
```

This runs in the background and writes:

```text
/workspace/logs/startup_healthcheck.log
/workspace/logs/wait_for_services.log
```

## Port notes

Inside the pod, Neo talks to local services through localhost-compatible URLs:

```text
Neo Studio:  http://127.0.0.1:7860
ComfyUI:     http://127.0.0.1:8188
KoboldCPP:   http://127.0.0.1:5001
```

Expose `7860` for the main Neo Studio UI. Exposing `8188` is useful for debugging ComfyUI directly. Expose `5001` only if you want direct KoboldCPP access.
