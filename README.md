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
docker build -t neo-studio-runpod:phase-a .
```

## Local run smoke test

```bash
docker run --gpus all --rm -it \
  -p 7860:7860 \
  -p 8188:8188 \
  -v neo-workspace:/workspace \
  -e MODEL_PROFILE=none \
  neo-studio-runpod:phase-a
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
```

See [`config/recommended-env.md`](config/recommended-env.md) for the full environment contract.

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

KoboldCPP is optional in Phase A. To enable it, provide a binary and model path:

```bash
START_KOBOLD=1
KOBOLDCPP_BIN=/workspace/koboldcpp/koboldcpp-linux-x64
KOBOLD_MODEL=/workspace/neo-models/text/model.gguf
```

Or provide a binary download URL:

```bash
INSTALL_KOBOLD=1
KOBOLDCPP_URL=https://example.com/koboldcpp-linux-x64
```

If KoboldCPP is not available, the pod still starts Neo Studio and ComfyUI. Neo text surfaces will show backend-disconnected diagnostics until a text backend is connected.

## Service logs

Logs are written to:

```text
/workspace/logs/neo_studio.log
/workspace/logs/comfyui.log
/workspace/logs/koboldcpp.log
```

Healthcheck helper:

```bash
/opt/neo-runpod/scripts/healthcheck.sh
```

## Current phase

This is **Phase A**: real pod-template shell.

Included:

- Dockerfile
- `/start.sh` entrypoint
- ComfyUI installer
- Neo Studio installer
- optional KoboldCPP installer
- custom-node installer
- multi-service launcher
- healthcheck helper
- recommended environment docs
- Docker ignore rules

Deferred to later phases:

- Runtime backend-profile patching for Linux pod defaults
- Deeper RunPod image-size optimization
- pinned release tags / lockfile strategy
- automated CI build validation
- optional prebuilt image publishing
