# Phase G — GHCR Docker image build and publish

This repo publishes the RunPod image through GitHub Actions to GitHub Container Registry.

## Published image

Use this image in RunPod after the workflow succeeds:

```text
ghcr.io/moodpixel/neo-runpod-template:phase-g
```

Useful alternatives:

```text
ghcr.io/moodpixel/neo-runpod-template:latest
ghcr.io/moodpixel/neo-runpod-template:sha-<short-commit-sha>
```

## Workflow

Workflow file:

```text
.github/workflows/publish-ghcr.yml
```

It builds `Dockerfile` from the repo root and pushes a Linux AMD64 image.

Default tags on `main`:

```text
phase-g
latest
sha-<short-commit-sha>
```

Manual workflow runs can also publish an extra tag through the `image_tag` input.

## First publish steps

1. Open the repository on GitHub.
2. Go to **Actions**.
3. Open **Build and publish GHCR image**.
4. Click **Run workflow**.
5. Use `main` branch.
6. Keep `image_tag=phase-g`.
7. Run the workflow.

## Required repository settings

The workflow uses `GITHUB_TOKEN` and requires package write permission:

```yaml
permissions:
  contents: read
  packages: write
```

If the workflow fails with a package permission error, check:

```text
Repo Settings -> Actions -> General -> Workflow permissions
```

Set it to allow read/write where needed.

## Important: make the GHCR package public or add credentials

RunPod can pull the image only if one of these is true:

1. The GHCR package is public.
2. RunPod has valid registry credentials for GHCR.

Recommended for this template test: make the package public.

After the first successful publish:

1. Open the package page for `neo-runpod-template` under the `MoodPixel` account/org.
2. Go to package settings.
3. Change visibility to **Public**.

If visibility stays private, RunPod may fail with:

```text
IMAGE_AUTH_ERROR: unauthorized
```

## Phase G.2 — Python dev headers for Comfy/Triton

A first RunPod boot exposed a ComfyUI startup crash while importing `comfy_kitchen` / Triton-generated helpers:

```text
fatal error: Python.h: No such file or directory
```

Phase G.2 adds these apt packages to the image:

```text
python3-dev
pkg-config
```

Reason:

- `python3-dev` provides `Python.h` for runtime/native Python extension compilation.
- `pkg-config` helps native package builds discover system library/compiler metadata.

After this patch, rebuild and publish the image again before retesting RunPod.

## RunPod container image value

Paste this into RunPod **Container image**:

```text
ghcr.io/moodpixel/neo-runpod-template:phase-g
```

Do not use placeholder image names like:

```text
yourdockerhub/neo-runpod-template:phase-f
```

## RunPod start command

Use:

```bash
/start.sh
```

## RunPod exposed HTTP ports

Use:

```text
7860,7861,8188,5001
```

Main ports for first testing:

```text
7860  Neo Studio
7861  Model Downloader
8188  ComfyUI direct debug
```

KoboldCPP is optional and stays off unless `START_KOBOLD=1`.

## First test env

Use a light first boot:

```bash
MODEL_PROFILE=none
START_NEO=1
START_COMFY=1
START_MODEL_DOWNLOADER=1
START_KOBOLD=0
INSTALL_CUSTOM_NODES=1
NEO_PATCH_PROFILES=1
COMFY_NODE_GROUPS=core,image
NEO_SCENE_DIRECTOR_MODE=symlink
MODEL_DOWNLOADER_TOKEN=your-private-token
```

After the basic pod works, expand Comfy nodes:

```bash
COMFY_NODE_GROUPS=core,image,video,finish
```

## Health checks inside the pod

```bash
/opt/neo-runpod/scripts/healthcheck.sh
cat /workspace/logs/healthcheck.tsv
cat /workspace/logs/healthcheck_summary.env
```

## Current status

This phase adds image publishing and the Python development headers required by Comfy/Triton runtime imports. It does not prove the image builds or boots successfully until the GitHub Actions workflow has run and the RunPod pod has been retested.
