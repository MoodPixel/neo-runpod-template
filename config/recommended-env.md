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
INSTALL_CUSTOM_NODES=1
INSTALL_NEO_MEMORY=1

# Update policy. Keep disabled for reproducible pods.
AUTO_UPDATE_NEO=0
AUTO_UPDATE_COMFY=0
AUTO_UPDATE_CUSTOM_NODES=0

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
KOBOLD_MODEL=/workspace/neo-models/text/model.gguf
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

## Port notes

Inside the pod, Neo talks to local services through localhost-compatible URLs:

```text
Neo Studio:  http://127.0.0.1:7860
ComfyUI:     http://127.0.0.1:8188
KoboldCPP:   http://127.0.0.1:5001
```

Expose `7860` for the main Neo Studio UI. Exposing `8188` is useful for debugging ComfyUI directly. Expose `5001` only if you want direct KoboldCPP access.
