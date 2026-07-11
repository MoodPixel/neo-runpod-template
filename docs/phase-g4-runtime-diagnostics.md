# Phase G.4 — Runtime diagnostics and Kobold lane hardening

Phase G.4 adds external diagnostics to the RunPod template without modifying the Neo Studio main repo.

## Why this phase exists

Two first-pod findings drove this phase:

1. `START_KOBOLD=1` was not enough to make KoboldCPP work because the lane still needs a real Linux KoboldCPP binary and a text GGUF model.
2. Neo image generation felt slower than direct ComfyUI for the same class of Qwen workflow, so the template needed one-command diagnostics before changing Neo code.

## KoboldCPP lane behavior

KoboldCPP remains optional by default.

```bash
START_KOBOLD=0
INSTALL_KOBOLD=0
KOBOLD_MODE=optional
KOBOLD_STRICT=0
KOBOLD_SUPERVISED=0
```

When `START_KOBOLD=1`, the template checks these paths:

```text
/workspace/koboldcpp/koboldcpp-linux-x64
/workspace/neo-models/text/model.gguf
```

or whatever is set through:

```bash
KOBOLDCPP_BIN=/workspace/koboldcpp/koboldcpp-linux-x64
KOBOLD_MODEL=/workspace/neo-models/text/model.gguf
```

If either file is missing, the service writes a clear status and skips Kobold unless strict/required mode is enabled.

## Important supervision change

Before Phase G.4, a started Kobold process was treated as a critical service. In Phase G.4, Kobold is not critical unless one of these is true:

```bash
KOBOLD_MODE=required
KOBOLD_STRICT=1
KOBOLD_SUPERVISED=1
```

That means Neo + Comfy stay alive during image testing even if the optional text lane fails.

## Kobold reports

Run these inside the pod:

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
/workspace/logs/koboldcpp.log
```

The checker lists up to 20 `.gguf` candidates found under:

```text
/workspace/neo-models/text
```

So if you download a model with the downloader but forget to set `KOBOLD_MODEL`, the report should make that obvious.

## Enabling Kobold correctly

Minimum shape:

```bash
START_KOBOLD=1
INSTALL_KOBOLD=1
KOBOLDCPP_URL=<direct-linux-koboldcpp-binary-url>
KOBOLD_MODEL=/workspace/neo-models/text/your-text-model.gguf
```

If the binary already exists:

```bash
START_KOBOLD=1
INSTALL_KOBOLD=0
KOBOLDCPP_BIN=/workspace/koboldcpp/koboldcpp-linux-x64
KOBOLD_MODEL=/workspace/neo-models/text/your-text-model.gguf
```

Only use this when you want the whole pod to fail if Kobold fails:

```bash
KOBOLD_MODE=required
# or
KOBOLD_STRICT=1
# or
KOBOLD_SUPERVISED=1
```

## Runtime diagnostics snapshot

Run:

```bash
/opt/neo-runpod/scripts/runtime_diagnostics.sh
```

It writes a timestamped snapshot under:

```text
/workspace/logs/runtime_diagnostics/<timestamp>
/workspace/logs/runtime_diagnostics/latest
```

Captured files include:

```text
service_http.tsv
nvidia_smi.txt
nvidia_smi_query.csv
comfyui.log.tail
neo_studio.log.tail
koboldcpp.log.tail
model_downloader.log.tail
kobold_lane_report.md
neo_image_log_index.tsv
```

Optional startup snapshot:

```bash
RUNTIME_DIAGNOSTICS_ON_START=1
```

This runs once in the background after services start and writes:

```text
/workspace/logs/runtime_diagnostics_startup.log
```

## Live generation timing trace

To investigate Neo-vs-direct-Comfy speed differences, run:

```bash
/opt/neo-runpod/scripts/trace_generation_timing.sh 240
```

Then trigger one generation during the trace window.

The trace writes to:

```text
/workspace/logs/generation_traces/<timestamp>
/workspace/logs/generation_traces/latest
```

Important files:

```text
gpu_samples.csv
after_comfyui.log.tail
after_neo_studio.log.tail
service_status.tsv
neo_image_log_index.tsv
```

## How to diagnose the slowdown

Use this rule:

| Finding | Meaning |
|---|---|
| Comfy log slow and GPU busy | Neo submitted a heavier/different workflow or params. |
| Comfy log fast but Neo UI late | Neo polling/output-copy/metadata completion is delayed. |
| GPU idle while Neo says running | provider/UI state tracking delay. |
| Direct Comfy and Neo use different size/steps/loader | not a fair speed comparison yet. |

Do not change Neo generation code until the trace shows where the extra time is spent.
