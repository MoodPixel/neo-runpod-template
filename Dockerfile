FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    aria2 \
    bash \
    build-essential \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    git-lfs \
    libgl1 \
    libglib2.0-0 \
    python3 \
    python3-pip \
    python3-venv \
    tini \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --upgrade pip setuptools wheel \
    && /opt/venv/bin/python -m pip install --index-url https://download.pytorch.org/whl/cu124 torch torchvision torchaudio

WORKDIR /workspace

COPY neo_download_models.py /opt/neo-runpod/neo_download_models.py
COPY start.sh /start.sh
COPY scripts/ /opt/neo-runpod/scripts/
COPY config/ /opt/neo-runpod/config/

RUN chmod +x /start.sh /opt/neo-runpod/scripts/*.sh

ENV NEO_REPO=https://github.com/MoodPixel/Neo_Studio_V2.git \
    NEO_BRANCH=main \
    NEO_ROOT=/workspace/Neo_Studio_V2 \
    COMFY_REPO=https://github.com/Comfy-Org/ComfyUI.git \
    COMFY_BRANCH=master \
    COMFY_ROOT=/workspace/ComfyUI \
    MODEL_ROOT=/workspace/neo-models \
    MODEL_PROFILE=none \
    START_NEO=1 \
    START_COMFY=1 \
    START_KOBOLD=0 \
    INSTALL_KOBOLD=0 \
    KOBOLD_MODE=optional \
    KOBOLD_STRICT=0 \
    START_MODEL_DOWNLOADER=1 \
    MODEL_DOWNLOADER_HOST=0.0.0.0 \
    MODEL_DOWNLOADER_PORT=7861 \
    MODEL_DOWNLOADER_TOKEN= \
    MODEL_DOWNLOADER_STRICT=0 \
    MODEL_DOWNLOADER_ALLOW_ANY_EXTENSION=0 \
    MODEL_DOWNLOADER_OVERWRITE=0 \
    INSTALL_CUSTOM_NODES=1 \
    INSTALL_NEO_MEMORY=1 \
    NEO_PATCH_PROFILES=1 \
    NEO_IMAGE_PROFILE_ID=comfyui_local \
    NEO_VIDEO_PROFILE_ID=video.comfyui \
    NEO_TEXT_PROFILE_ID=local_koboldcpp_text \
    COMFY_NODE_GROUPS=core,image,video,finish \
    INSTALL_CUSTOM_NODE_REQUIREMENTS=1 \
    RUN_CUSTOM_NODE_INSTALLERS=0 \
    NEO_SCENE_DIRECTOR_MODE=symlink \
    CHECK_COMFY_NODES=0 \
    COMFY_NODES_STRICT=0 \
    CHECK_KOBOLDCPP_LANE=1 \
    CHECK_KOBOLD_API_REQUIRED=0 \
    HEALTHCHECK_TIMEOUT=5 \
    HEALTHCHECK_STRICT=0 \
    CHECK_COMFY_OBJECT_INFO=0 \
    RUN_STARTUP_HEALTHCHECK=0 \
    HEALTH_WAIT_TIMEOUT_SECONDS=300 \
    HEALTH_WAIT_INTERVAL_SECONDS=5 \
    AUTO_UPDATE_NEO=0 \
    AUTO_UPDATE_COMFY=0 \
    AUTO_UPDATE_CUSTOM_NODES=0 \
    NEO_HOST=0.0.0.0 \
    NEO_PORT=7860 \
    COMFY_HOST=0.0.0.0 \
    COMFY_PORT=8188 \
    COMFY_PREVIEW_METHOD=auto \
    KOBOLD_HOST=0.0.0.0 \
    KOBOLD_PORT=5001 \
    KOBOLDCPP_ROOT=/workspace/koboldcpp \
    KOBOLDCPP_BIN=/workspace/koboldcpp/koboldcpp-linux-x64 \
    KOBOLD_MODEL=/workspace/neo-models/text/model.gguf \
    KOBOLD_TIMEOUT_SECONDS=300

EXPOSE 7860 7861 8188 5001

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/start.sh"]
