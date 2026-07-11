# Neo Studio RunPod Template

Persistent RunPod pod template for running **Neo Studio V2** as the main creative control UI with **ComfyUI** as the image/video backend, an optional **KoboldCPP** local text lane, and an on-demand model downloader.

This repository is the pod-template layer only. It does not modify the Neo Studio source repository.

## Runtime layout

The pod uses `/workspace` as the persistent root:

```text
/workspace/Neo_Studio_V2      # Neo Studio checkout
/workspace/ComfyUI            # ComfyUI checkout
/workspace/koboldcpp          # Optional KoboldCPP binary area
/workspace/neo-models         # Shared persistent model bank
/workspace/logs               # Service logs and diagnostics
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
| Model Downloader | `7861` | Yes | On-demand model download UI/API |
| ComfyUI | `8188` | Yes | Image and video generation backend |
| KoboldCPP | `5001` | No | Local text backend for Assistant / Roleplay / Prompting |

Expose port `7860` in RunPod for the Neo Studio UI. Expose `7861` only when you want the model downloader UI. Expose `8188` only when you want direct ComfyUI debugging. Expose `5001` only when running KoboldCPP directly.

## Build

```bash
docker build -t neo-studio-runpod:phase-g4 .
```

## Local run smoke test

```bash
docker run --gpus all --rm -it \
  -p 7860:7860 \
  -p 7861:7861 \
  -p 8188:8188 \
  -v neo-workspace:/workspace \
  -e MODEL_PROFILE=none \
  neo-studio-runpod:phase-g4
```

Open:

```text
http://localhost:7860
http://localhost:7861
```

## RunPod template settings

Recommended container start command:

```bash
/start.sh
```

Recommended exposed HTTP ports:

```text
7860,7861,8188,5001
```

Minimum environment:

```bash
NEO_REPO=https://github.com/MoodPixel/Neo_Studio_V2.git
NEO_BRANCH=main
MODEL_PROFILE=none
START_NEO=1
START_COMFY=1
START_MODEL_DOWNLOADER=1
START_KOBOLD=0
INSTALL_CUSTOM_NODES=1
NEO_PATCH_PROFILES=1
COMFY_NODE_GROUPS=core,image,video,finish
NEO_SCENE_DIRECTOR_MODE=symlink
KOBOLD_MODE=optional
KOBOLD_SUPERVISED=0
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

### Neo Scene Director custom node

Neo Studio's main repository contains a root-level Comfy node folder:

```text
/workspace/Neo_Studio_V2/neo_scene_director
```

The template links it into:

```text
/workspace/ComfyUI/custom_nodes/neo_scene_director
```

Default mode:

```bash
NEO_SCENE_DIRECTOR_MODE=symlink
```

This keeps Comfy using the current Neo checkout copy without duplicating or modifying the Neo source.

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

That prepares folders only. It does not download large model packs.

## On-demand model downloader

Phase F adds a separate template-owned model downloader:

```text
/opt/neo-runpod/scripts/model_downloader_server.py
```

Default URL:

```text
http://127.0.0.1:7861
```

It is enabled by default:

```bash
START_MODEL_DOWNLOADER=1
MODEL_DOWNLOADER_PORT=7861
```

The downloader UI provides:

- a category dropdown;
- URL input;
- optional filename override;
- job progress/status table;
- automatic target folder routing under `/workspace/neo-models`.

The category contract lives in:

```text
/opt/neo-runpod/config/model-download-categories.tsv
```

Common mappings:

```text
checkpoints      -> /workspace/neo-models/ckpt_bank
loras            -> /workspace/neo-models/loras
vae              -> /workspace/neo-models/vae
controlnet       -> /workspace/neo-models/controlnet
upscale_models   -> /workspace/neo-models/upscale_models
text_gguf        -> /workspace/neo-models/text
other            -> /workspace/neo-models/other
```

Supported download source style:

```text
Hugging Face direct file URLs
CivitAI download URLs
GitHub release/direct URLs
Any direct http/https model file URL
```

Tokens are supplied as runtime environment variables, not baked into the image:

```bash
HF_TOKEN=          # sent to huggingface.co URLs
CIVITAI_TOKEN=     # sent to civitai.com URLs
```

If you expose port `7861`, set a downloader token:

```bash
MODEL_DOWNLOADER_TOKEN=your-private-token
```

The downloader writes logs/status here:

```text
/workspace/logs/model_downloader.log
/workspace/logs/model_downloader_jobs.jsonl
```

By default, the downloader is not critical. If it crashes, Neo + Comfy should keep running:

```bash
MODEL_DOWNLOADER_SUPERVISED=0
```

Make it critical only when intentionally validating it:

```bash
MODEL_DOWNLOADER_SUPERVISED=1
MODEL_DOWNLOADER_STRICT=1
```

## KoboldCPP optional lane

Phase D introduced the optional lane. Phase G.4 hardens its reports and supervision behavior.

Disabled default:

```bash
START_KOBOLD=0
KOBOLD_MODE=optional
KOBOLD_STRICT=0
KOBOLD_SUPERVISED=0
```

This is intentional. The pod should still start Neo Studio and ComfyUI when no text model exists. Neo text/assistant/roleplay surfaces can show backend-disconnected diagnostics until a text backend is connected.

To enable local text generation, provide both a KoboldCPP executable and a GGUF model:

```bash
START_KOBOLD=1
KOBOLDCPP_BIN=/workspace/koboldcpp/koboldcpp-linux-x64
KOBOLD_MODEL=/workspace/neo-models/text/model.gguf
```

To download the binary at startup, also set:

```bash
INSTALL_KOBOLD=1
KOBOLDCPP_URL=<direct-linux-koboldcpp-binary-url>
```

Kobold is only critical when one of these is enabled:

```bash
KOBOLD_MODE=required
KOBOLD_STRICT=1
KOBOLD_SUPERVISED=1
```

Diagnostics:

```bash
/opt/neo-runpod/scripts/check_koboldcpp.sh
/opt/neo-runpod/scripts/kobold_lane_report.sh
```

Report files:

```text
/workspace/logs/koboldcpp_status.env
/workspace/logs/koboldcpp_runtime_status.env
/workspace/logs/koboldcpp_check.tsv
/workspace/logs/koboldcpp_check_summary.env
/workspace/logs/kobold_lane_report.md
/workspace/logs/kobold_lane_report.tsv
```

## Runtime diagnostics

Phase G.4 adds a one-command diagnostic snapshot:

```bash
/opt/neo-runpod/scripts/runtime_diagnostics.sh
```

It writes:

```text
/workspace/logs/runtime_diagnostics/<timestamp>
/workspace/logs/runtime_diagnostics/latest
```

For Neo-vs-direct-Comfy speed checks, run:

```bash
/opt/neo-runpod/scripts/trace_generation_timing.sh 240
```

Then trigger a generation during the trace window.

See [`docs/phase-g4-runtime-diagnostics.md`](docs/phase-g4-runtime-diagnostics.md) for the full diagnosis workflow.

## Health checks and readiness

Phase E adds a richer diagnostics layer:

```bash
/opt/neo-runpod/scripts/healthcheck.sh
/opt/neo-runpod/scripts/wait_for_services.sh
```

`healthcheck.sh` checks the enabled services and writes:

```text
/workspace/logs/healthcheck.tsv
/workspace/logs/healthcheck_summary.env
```

Required checks by default:

```text
Neo Studio /api/health when START_NEO=1
ComfyUI /system_stats when START_COMFY=1
```

Optional checks:

```text
Model downloader /health when START_MODEL_DOWNLOADER=1
KoboldCPP lane when START_KOBOLD=1 and KOBOLD_MODE=optional
Comfy custom-node manifest when CHECK_COMFY_NODES=1
Comfy /object_info when CHECK_COMFY_OBJECT_INFO=1
```

Useful commands:

```bash
/opt/neo-runpod/scripts/healthcheck.sh
/opt/neo-runpod/scripts/wait_for_services.sh
```

## Service logs

Logs are written to:

```text
/workspace/logs/neo_studio.log
/workspace/logs/comfyui.log
/workspace/logs/model_downloader.log
/workspace/logs/model_downloader_jobs.jsonl
/workspace/logs/koboldcpp.log
/workspace/logs/comfy_nodes_status.tsv
/workspace/logs/comfy_nodes_check.tsv
/workspace/logs/koboldcpp_status.env
/workspace/logs/koboldcpp_runtime_status.env
/workspace/logs/koboldcpp_check.tsv
/workspace/logs/koboldcpp_check_summary.env
/workspace/logs/kobold_lane_report.md
/workspace/logs/healthcheck.tsv
/workspace/logs/healthcheck_summary.env
/workspace/logs/wait_for_services.log
/workspace/logs/runtime_diagnostics/
/workspace/logs/generation_traces/
```

## Current phase

This is **Phase G.4**: runtime diagnostics and Kobold lane hardening.

Included:

- Dockerfile
- `/start.sh` entrypoint
- ComfyUI installer
- Neo Studio installer
- hardened optional KoboldCPP installer
- manifest-driven custom-node installer
- Comfy node manifest
- model download category manifest
- on-demand model downloader UI/API
- Neo Scene Director sync/link into ComfyUI custom_nodes
- Comfy node audit helper
- KoboldCPP lane checker
- Kobold lane markdown/TSV report
- richer healthcheck helper
- readiness wait helper
- runtime diagnostics snapshot helper
- generation timing trace helper
- optional startup diagnostics snapshot
- multi-service launcher
- recommended environment docs
- Docker ignore rules
- runtime-only Neo backend profile patcher

Deferred to later phases:

- Deeper RunPod image-size optimization
- Full container build/test validation on GPU hardware
- Neo-side timing instrumentation if external traces prove the delay is inside Neo polling/output handling
