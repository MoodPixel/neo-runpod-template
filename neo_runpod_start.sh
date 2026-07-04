#!/usr/bin/env bash
set -euo pipefail

export NVIDIA_VISIBLE_DEVICES="${NVIDIA_VISIBLE_DEVICES:-all}"
unset CUDA_VISIBLE_DEVICES || true
export CUDA_DEVICE_ORDER="${CUDA_DEVICE_ORDER:-PCI_BUS_ID}"

echo "======================================"
echo "Neo RunPod bootstrap"
echo "MODEL_PROFILE=${MODEL_PROFILE:-none}"
echo "NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}"
echo "CUDA_DEVICE_ORDER=${CUDA_DEVICE_ORDER}"
echo "======================================"

if [[ -z "${NEO_DOWNLOADER_URL:-}" ]]; then
  echo "NEO_DOWNLOADER_URL is not set."
  echo "Set it to your raw GitHub URL for neo_download_models.py."
  exit 1
fi

echo "Downloading Neo downloader:"
echo "${NEO_DOWNLOADER_URL}"

curl -fsSL "${NEO_DOWNLOADER_URL}" -o /notebooks/download_models.py

echo "Neo downloader installed at /notebooks/download_models.py"
echo "Starting base template script..."

bash /notebooks/start.sh
