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
CIVITAI_TOKEN=

# Service toggles
START_NEO=1
START_COMFY=1
START_KOBOLD=0
INSTALL_KOBOLD=0
KOBOLD_MODE=optional
KOBOLD_STRICT=0
KOBOLD_SUPERVISED=0
START_MODEL_DOWNLOADER=1
INSTALL_CUSTOM_NODES=1
INSTALL_NEO_MEMORY=1

# Runtime backend-profile patching
NEO_PATCH_PROFILES=1
NEO_COMFY_BASE_URL=http://127.0.0.1:8188
NEO_KOBOLD_BASE_URL=http://127.0.0.1:5001
NEO_IMAGE_PROFILE_ID=comfyui_local
NEO_VIDEO_PROFILE_ID=video.comfyui
NEO_TEXT_PROFILE_ID=local_koboldcpp_text

# On-demand model downloader
MODEL_DOWNLOADER_HOST=0.0.0.0
MODEL_DOWNLOADER_PORT=7861
MODEL_DOWNLOADER_TOKEN=
MODEL_DOWNLOADER_STRICT=0
MODEL_DOWNLOADER_SUPERVISED=0
MODEL_DOWNLOADER_ALLOW_ANY_EXTENSION=0
MODEL_DOWNLOADER_OVERWRITE=0
MODEL_CATEGORY_MANIFEST=/opt/neo-runpod/config/model-download-categories.tsv

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

# Runtime diagnostics
RUNTIME_DIAGNOSTICS_ON_START=0
TRACE_DURATION_SECONDS=240
TRACE_INTERVAL_SECONDS=1

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

Available model profiles are defined in `neo_download_models.py`. Useful values include:

```bash
MODEL_PROFILE=none
MODEL_PROFILE=image_core
MODEL_PROFILE=video_core
MODEL_PROFILE=rapid_video_core
MODEL_PROFILE=all
```

Use `HF_TOKEN` when a model requires Hugging Face authentication. Use `CIVITAI_TOKEN` for authenticated CivitAI download URLs. These are runtime environment variables and are not baked into the Docker image.

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

## On-demand model downloader

The downloader UI/API runs on port `7861` when enabled:

```bash
START_MODEL_DOWNLOADER=1
MODEL_DOWNLOADER_PORT=7861
```

It writes only under:

```text
/workspace/neo-models
```

Common category mappings:

```text
checkpoints      -> /workspace/neo-models/ckpt_bank
loras            -> /workspace/neo-models/loras
vae              -> /workspace/neo-models/vae
controlnet       -> /workspace/neo-models/controlnet
text_gguf        -> /workspace/neo-models/text
upscale_models   -> /workspace/neo-models/upscale_models
```

Supported source style:

```text
Hugging Face direct file URLs
CivitAI download URLs
GitHub release/direct URLs
Any direct http/https model file URL
```

If you expose port `7861`, set:

```bash
MODEL_DOWNLOADER_TOKEN=your-private-token
```

Downloader logs:

```text
/workspace/logs/model_downloader_jobs.jsonl
/workspace/logs/model_downloader.log
```

## Comfy custom-node hardening

Default enabled groups:

```bash
COMFY_NODE_GROUPS=core,image,video,finish
```

Use a smaller set when testing image-only pods:

```bash
COMFY_NODE_GROUPS=core,image
```

Neo's own Scene Director node is synced from the Neo checkout into ComfyUI:

```bash
NEO_SCENE_DIRECTOR_MODE=symlink
```

Node audit reports:

```text
/workspace/logs/comfy_nodes_status.tsv
/workspace/logs/comfy_nodes_check.tsv
```

## KoboldCPP optional text lane

KoboldCPP is disabled by default:

```bash
START_KOBOLD=0
```

To enable local text generation, provide both a KoboldCPP executable and a GGUF model:

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

The lane is optional by default. Even when `START_KOBOLD=1`, it does not stop Neo + Comfy unless strict/supervised mode is enabled:

```bash
KOBOLD_MODE=optional
KOBOLD_STRICT=0
KOBOLD_SUPERVISED=0
```

Make Kobold critical only when intentionally validating it:

```bash
KOBOLD_MODE=required
# or
KOBOLD_STRICT=1
# or
KOBOLD_SUPERVISED=1
```

Kobold lane reports:

```text
/workspace/logs/koboldcpp_status.env
/workspace/logs/koboldcpp_runtime_status.env
/workspace/logs/koboldcpp_check.tsv
/workspace/logs/koboldcpp_check_summary.env
/workspace/logs/kobold_lane_report.md
/workspace/logs/kobold_lane_report.tsv
```

Useful commands:

```bash
/opt/neo-runpod/scripts/check_koboldcpp.sh
/opt/neo-runpod/scripts/kobold_lane_report.sh
```

## Runtime diagnostics and generation timing

One-shot runtime snapshot:

```bash
/opt/neo-runpod/scripts/runtime_diagnostics.sh
```

Snapshot output:

```text
/workspace/logs/runtime_diagnostics/<timestamp>
/workspace/logs/runtime_diagnostics/latest
```

Live Neo-vs-Comfy timing trace:

```bash
/opt/neo-runpod/scripts/trace_generation_timing.sh 240
```

Trace output:

```text
/workspace/logs/generation_traces/<timestamp>
/workspace/logs/generation_traces/latest
```

Enable one automatic startup snapshot only when debugging:

```bash
RUNTIME_DIAGNOSTICS_ON_START=1
```

## Health checks and readiness

```bash
/opt/neo-runpod/scripts/healthcheck.sh
/opt/neo-runpod/scripts/wait_for_services.sh
```

Health reports:

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
Model downloader /health
KoboldCPP lane
Comfy custom-node manifest check
Comfy /object_info check
```

To run the readiness loop automatically after services start:

```bash
RUN_STARTUP_HEALTHCHECK=1
```

## Port notes

Inside the pod, Neo talks to local services through localhost-compatible URLs:

```text
Neo Studio:        http://127.0.0.1:7860
Model Downloader: http://127.0.0.1:7861
ComfyUI:           http://127.0.0.1:8188
KoboldCPP:         http://127.0.0.1:5001
```

Expose `7860` for the main Neo Studio UI. Expose `7861` only when you want the model downloader UI. Expose `8188` only when you want direct ComfyUI debugging. Expose `5001` only if you want direct KoboldCPP access.
