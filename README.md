# Neo Studio RunPod Template

Persistent RunPod pod template for running **Neo Studio V2** as the main creative control UI with **ComfyUI** as the image/video backend and optional **KoboldCPP** as the local text backend.

This repository is the pod-template layer only. It does not modify the Neo Studio source repository.

## Runtime layout

The pod uses `/workspace` as the persistent root:

```text
/workspace/Neo_Studio_V2      # Neo Studio checkout
/workspace/ComfyUI            # ComfyUI checkout
/workspace/koboldcpp          # Optional KoboldCPP binary area
/workspace/neo-models         # Shared persistent model bank
/workspace/logs               # Service logs
```

Neo runtime/user data stays inside:

```text
/workspace/Neo_Studio_V2/neo_data
```

That folder is intentionally runtime state, not source code.

## Services

| Service | Default port | Enabled by default | Purpose |
|---|---:|---:|---|
| Neo Studio | `7860` | Yes | Main UI / control layer |
| ComfyUI | `8188` | Yes | Image and video generation backend |
| KoboldCPP | `5001` | No | Local text backend for Assistant / Roleplay / Prompting |

Expose port `7860` in RunPod for the Neo Studio UI. Expose `8188` only when you want direct ComfyUI debugging. Expose `5001` only when running KoboldCPP directly.

## Build

```bash
docker build -t neo-studio-runpod:phase-c .
```

## Local run smoke test

```bash
docker run --gpus all --rm -it \
  -p 7860:7860 \
  -p 8188:8188 \
  -v neo-workspace:/workspace \
  -e MODEL_PROFILE=none \
  neo-studio-runpod:phase-c
```

Open:

```text
http://localhost:7860
```

## RunPod template settings

Recommended container start command:

```bash
/start.sh
```

Recommended exposed HTTP ports:

```text
7860,8188,5001
```

Minimum environment:

```bash
NEO_REPO=https://github.com/MoodPixel/Neo_Studio_V2.git
NEO_BRANCH=main
MODEL_PROFILE=none
START_NEO=1
START_COMFY=1
START_KOBOLD=0
INSTALL_CUSTOM_NODES=1
NEO_PATCH_PROFILES=1
COMFY_NODE_GROUPS=core,image,video,finish
NEO_SCENE_DIRECTOR_MODE=symlink
```

See [`config/recommended-env.md`](config/recommended-env.md) for the full environment contract.

## Runtime backend profile patching

Phase B adds a runtime-only backend profile patcher:

```text
/opt/neo-runpod/scripts/patch_neo_profiles.py
```

The patcher runs from `/start.sh` after Neo is installed and before services start. It writes only under:

```text
/workspace/Neo_Studio_V2/neo_data/settings/backends
```

It does not edit files inside the Neo source checkout.

Default RunPod mapping:

```text
image             -> comfyui_local
video             -> video.comfyui
text              -> local_koboldcpp_text
assistant         -> local_koboldcpp_text
prompt_captioning -> local_koboldcpp_text
roleplay          -> local_koboldcpp_text
```

Default backend URLs:

```text
ComfyUI:   http://127.0.0.1:8188
KoboldCPP: http://127.0.0.1:5001
```

Useful overrides:

```bash
NEO_PATCH_PROFILES=1
NEO_COMFY_BASE_URL=http://127.0.0.1:8188
NEO_KOBOLD_BASE_URL=http://127.0.0.1:5001
NEO_IMAGE_PROFILE_ID=comfyui_local
NEO_VIDEO_PROFILE_ID=video.comfyui
NEO_TEXT_PROFILE_ID=local_koboldcpp_text
```

Disable patching for debugging only:

```bash
NEO_PATCH_PROFILES=0
```

## Comfy custom-node hardening

Phase C hardens Comfy setup around Neo's recommended custom-node list.

The third-party node contract lives in:

```text
/opt/neo-runpod/config/comfy-node-manifest.tsv
```

The installer is:

```text
/opt/neo-runpod/scripts/install_custom_nodes.sh
```

It installs the manifest groups enabled by:

```bash
COMFY_NODE_GROUPS=core,image,video,finish
```

Useful smaller modes:

```bash
COMFY_NODE_GROUPS=core,image
COMFY_NODE_GROUPS=core,video
```

Install behavior:

```bash
INSTALL_CUSTOM_NODE_REQUIREMENTS=1
RUN_CUSTOM_NODE_INSTALLERS=0
COMFY_NODES_STRICT=0
```

`RUN_CUSTOM_NODE_INSTALLERS` stays disabled by default because `install.py` files are third-party executable code. Requirements are installed by default because most Comfy custom nodes need them to import correctly.

### Neo Scene Director custom node

Neo Studio's main repository contains a root-level Comfy node folder:

```text
/workspace/Neo_Studio_V2/neo_scene_director
```

The Phase C template links it into:

```text
/workspace/ComfyUI/custom_nodes/neo_scene_director
```

Default mode:

```bash
NEO_SCENE_DIRECTOR_MODE=symlink
```

This keeps Comfy using the current Neo checkout copy without duplicating or modifying the Neo source. Alternatives:

```bash
NEO_SCENE_DIRECTOR_MODE=copy
NEO_SCENE_DIRECTOR_MODE=skip
```

### Node audit reports

The installer writes:

```text
/workspace/logs/comfy_nodes_status.tsv
```

A separate checker is available:

```bash
/opt/neo-runpod/scripts/check_comfy_nodes.sh
```

Enable it inside the healthcheck only when needed:

```bash
CHECK_COMFY_NODES=1
```

## Model handling

`neo_download_models.py` prepares Comfy model folders under:

```text
/workspace/neo-models
```

It also writes ComfyUI `extra_model_paths.yaml` so Comfy can discover models from the shared model bank instead of duplicating files inside ComfyUI.

Safe default:

```bash
MODEL_PROFILE=none
```

Useful larger profiles:

```bash
MODEL_PROFILE=image_core
MODEL_PROFILE=video_core
MODEL_PROFILE=rapid_video_core
MODEL_PROFILE=all
```

Use `HF_TOKEN` when a Hugging Face model requires authentication.

## KoboldCPP lane

KoboldCPP is optional in Phase C. To enable it, provide a binary and model path:

```bash
START_KOBOLD=1
KOBOLDCPP_BIN=/workspace/koboldcpp/koboldcpp-linux-x64
KOBOLD_MODEL=/workspace/neo-models/text/model.gguf
```

If KoboldCPP is not available, the pod still starts Neo Studio and ComfyUI. Neo text surfaces will show backend-disconnected diagnostics until a text backend is connected.

## Service logs

Logs are written to:

```text
/workspace/logs/neo_studio.log
/workspace/logs/comfyui.log
/workspace/logs/koboldcpp.log
/workspace/logs/comfy_nodes_status.tsv
/workspace/logs/comfy_nodes_check.tsv
```

Healthcheck helper:

```bash
/opt/neo-runpod/scripts/healthcheck.sh
```

## Current phase

This is **Phase C**: Comfy hardening.

Included:

- Dockerfile
- `/start.sh` entrypoint
- ComfyUI installer
- Neo Studio installer
- optional KoboldCPP installer
- manifest-driven custom-node installer
- Comfy node manifest
- Neo Scene Director sync/link into ComfyUI custom_nodes
- Comfy node audit helper
- multi-service launcher
- healthcheck helper
- recommended environment docs
- Docker ignore rules
- runtime-only Neo backend profile patcher

Deferred to later phases:

- Deeper RunPod image-size optimization
- Full container build/test validation on GPU hardware
