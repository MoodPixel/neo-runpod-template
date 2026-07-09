import os
import shutil
import subprocess
from pathlib import Path

MODEL_PROFILE = os.environ.get("MODEL_PROFILE", "none").strip().lower()
HF_TOKEN = os.environ.get("HF_TOKEN")

COMFY_ROOT = Path("/workspace/ComfyUI")
MODEL_ROOT = Path("/workspace/neo-models")

FOLDERS = [
    "ckpt_bank",
    "diffusion_models",
    "unet",
    "text_encoders",
    "clip",
    "clip_vision",
    "vae",
    "loras",
    "controlnet",
    "upscale_models",
    "embeddings",
    "ipadapter",
    "insightface",
    "style_models",
    "motion_models",
    "wildcards",
    "text",
    "other",
    "SEEDVR2",
]

YAML_TEXT = """neo_models:
  base_path: /workspace/neo-models

  checkpoints: ckpt_bank

  diffusion_models: |
    diffusion_models
    unet

  unet: |
    unet
    diffusion_models

  text_encoders: |
    text_encoders
    clip

  clip: clip
  clip_vision: clip_vision
  vae: vae
  loras: loras
  controlnet: controlnet
  upscale_models: upscale_models
  embeddings: embeddings
  ipadapter: ipadapter
  insightface: insightface
  style_models: style_models
  motion_models: motion_models
  wildcards: wildcards
  other: other
"""

PROFILES = {
    "none": [],

    "wan22_i2v": [
        {
            "repo_id": "Comfy-Org/Wan_2.2_ComfyUI_Repackaged",
            "filename": "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors",
            "folder": "diffusion_models",
        },
        {
            "repo_id": "Comfy-Org/Wan_2.2_ComfyUI_Repackaged",
            "filename": "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors",
            "folder": "diffusion_models",
        },
        {
            "repo_id": "Comfy-Org/Wan_2.2_ComfyUI_Repackaged",
            "filename": "split_files/text_encoders/umt5_xxl_fp16.safetensors",
            "folder": "text_encoders",
        },
        {
            "repo_id": "Comfy-Org/Wan_2.2_ComfyUI_Repackaged",
            "filename": "split_files/vae/wan2.2_vae.safetensors",
            "folder": "vae",
        },
        {
            "repo_id": "Comfy-Org/Wan_2.2_ComfyUI_Repackaged",
            "filename": "split_files/vae/wan_2.1_vae.safetensors",
            "folder": "vae",
        },
    ],

    "ltx23": [
        {
            "repo_id": "QuantStack/LTX-2.3-GGUF",
            "filename": "LTX-2.3-dev/LTX-2.3-dev-Q5_K_M.gguf",
            "folder": "diffusion_models",
        },
        {
            "repo_id": "Kijai/LTX2.3_comfy",
            "filename": "text_encoders/ltx-2.3_text_projection_bf16.safetensors",
            "folder": "text_encoders",
        },
        {
            "repo_id": "Kijai/LTX2.3_comfy",
            "filename": "vae/LTX23_audio_vae_bf16.safetensors",
            "folder": "vae",
        },
        {
            "repo_id": "Kijai/LTX2.3_comfy",
            "filename": "vae/LTX23_video_vae_bf16.safetensors",
            "folder": "vae",
        },
    ],

    "qwen_rapid": [
        {
            "repo_id": "Phr00t/Qwen-Image-Edit-Rapid-AIO",
            "filename": "v19/Qwen-Rapid-AIO-NSFW-v19.safetensors",
            "folder": "diffusion_models",
            "also_link_to": ["ckpt_bank"],
        },
    ],

    "flux2_klein": [
        {
            "repo_id": "black-forest-labs/FLUX.2-klein-9B",
            "filename": "flux-2-klein-9b.safetensors",
            "folder": "diffusion_models",
        },
        {
            "repo_id": "Comfy-Org/vae-text-encorder-for-flux-klein-9b",
            "filename": "split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors",
            "folder": "text_encoders",
        },
        {
            "repo_id": "Comfy-Org/vae-text-encorder-for-flux-klein-9b",
            "filename": "split_files/vae/flux2-vae.safetensors",
            "folder": "vae",
        },
    ],

    "seedvr2_fast": [
        {
            "repo_id": "numz/SeedVR2_comfyUI",
            "filename": "ema_vae_fp16.safetensors",
            "folder": "SEEDVR2",
        },
        {
            "repo_id": "numz/SeedVR2_comfyUI",
            "filename": "seedvr2_ema_3b_fp8_e4m3fn.safetensors",
            "folder": "SEEDVR2",
        },
    ],

    "seedvr2_quality": [
        {
            "repo_id": "numz/SeedVR2_comfyUI",
            "filename": "ema_vae_fp16.safetensors",
            "folder": "SEEDVR2",
        },
        {
            "repo_id": "numz/SeedVR2_comfyUI",
            "filename": "seedvr2_ema_7b_sharp_fp8_e4m3fn.safetensors",
            "folder": "SEEDVR2",
        },
    ],

    "seedvr2_all": [
        {
            "repo_id": "numz/SeedVR2_comfyUI",
            "filename": "ema_vae_fp16.safetensors",
            "folder": "SEEDVR2",
        },
        {
            "repo_id": "numz/SeedVR2_comfyUI",
            "filename": "seedvr2_ema_3b_fp8_e4m3fn.safetensors",
            "folder": "SEEDVR2",
        },
        {
            "repo_id": "numz/SeedVR2_comfyUI",
            "filename": "seedvr2_ema_7b_sharp_fp8_e4m3fn.safetensors",
            "folder": "SEEDVR2",
        },
    ],

    "flux2_controlnet": [
        {
            "repo_id": "alibaba-pai/FLUX.2-dev-Fun-Controlnet-Union",
            "filename": "FLUX.2-dev-Fun-Controlnet-Union-2602.safetensors",
            "folder": "controlnet",
        },
    ],

    "qwen_controlnet": [
        {
            "repo_id": "f5aiteam/ComfyUI",
            "filename": "ControlNet/Qwen-Image-InstantX-Controlnet-Union.safetensors",
            "folder": "controlnet",
        },
        {
            "repo_id": "InstantX/Qwen-Image-ControlNet-Inpainting",
            "filename": "diffusion_pytorch_model.safetensors",
            "folder": "controlnet",
            "output_name": "Qwen-Image-ControlNet-Inpainting.safetensors",
        },
    ],

    "wan_rapid_aio_t2v": [
        {
            "repo_id": "Phr00t/WAN2.2-14B-Rapid-AllInOne",
            "filename": "v10/wan2.2-t2v-rapid-aio-v10-nsfw.safetensors",
            "folder": "ckpt_bank",
            "also_link_to": ["diffusion_models"],
        },
    ],

    "wan_rapid_aio_i2v": [
        {
            "repo_id": "Phr00t/WAN2.2-14B-Rapid-AllInOne",
            "filename": "v10/wan2.2-i2v-rapid-aio-v10-nsfw.safetensors",
            "folder": "ckpt_bank",
            "also_link_to": ["diffusion_models"],
        },
    ],

    "wan_rapid_aio": [
        {
            "repo_id": "Phr00t/WAN2.2-14B-Rapid-AllInOne",
            "filename": "v10/wan2.2-t2v-rapid-aio-v10-nsfw.safetensors",
            "folder": "ckpt_bank",
            "also_link_to": ["diffusion_models"],
        },
        {
            "repo_id": "Phr00t/WAN2.2-14B-Rapid-AllInOne",
            "filename": "v10/wan2.2-i2v-rapid-aio-v10-nsfw.safetensors",
            "folder": "ckpt_bank",
            "also_link_to": ["diffusion_models"],
        },
    ],
}

PROFILES["video_core"] = (
    PROFILES["wan22_i2v"]
    + PROFILES["ltx23"]
    + PROFILES["seedvr2_quality"]
)

PROFILES["rapid_video_core"] = (
    PROFILES["wan_rapid_aio"]
    + PROFILES["ltx23"]
    + PROFILES["seedvr2_quality"]
)

PROFILES["image_core"] = (
    PROFILES["qwen_rapid"]
    + PROFILES["flux2_klein"]
    + PROFILES["flux2_controlnet"]
    + PROFILES["qwen_controlnet"]
)

PROFILES["all"] = (
    PROFILES["video_core"]
    + PROFILES["rapid_video_core"]
    + PROFILES["image_core"]
)


def ensure_base():
    print("======================================")
    print(f"Neo Model Profile: {MODEL_PROFILE}")
    print("Neo: preparing custom model paths")
    print("======================================")

    for folder in FOLDERS:
        path = MODEL_ROOT / folder
        path.mkdir(parents=True, exist_ok=True)
        print(f"Neo: ensured {path}")

    if COMFY_ROOT.exists():
        target = COMFY_ROOT / "extra_model_paths.yaml"
        target.write_text(YAML_TEXT)
        print(f"Neo: wrote {target}")
        ensure_seedvr2_symlink()
        ensure_res4lyf_custom_node()
    else:
        print("Neo warning: /workspace/ComfyUI does not exist yet.")


def ensure_seedvr2_symlink():
    seedvr2_real = MODEL_ROOT / "SEEDVR2"
    seedvr2_real.mkdir(parents=True, exist_ok=True)

    comfy_models_dir = COMFY_ROOT / "models"
    comfy_models_dir.mkdir(parents=True, exist_ok=True)

    seedvr2_path = comfy_models_dir / "SEEDVR2"

    if seedvr2_path.is_symlink():
        print(f"Neo: SeedVR2 symlink already exists: {seedvr2_path} -> {seedvr2_path.resolve()}")
        return

    if seedvr2_path.exists():
        if seedvr2_path.is_dir():
            try:
                is_empty = not any(seedvr2_path.iterdir())
            except Exception:
                is_empty = False

            if is_empty:
                seedvr2_path.rmdir()
                seedvr2_path.symlink_to(seedvr2_real, target_is_directory=True)
                print(f"Neo: linked {seedvr2_path} -> {seedvr2_real}")
            else:
                print(f"Neo warning: {seedvr2_path} exists and is not empty.")
                print("Neo warning: SeedVR2 files are still stored in /workspace/neo-models/SEEDVR2.")
        else:
            print(f"Neo warning: {seedvr2_path} exists but is not a directory.")
        return

    seedvr2_path.symlink_to(seedvr2_real, target_is_directory=True)
    print(f"Neo: linked {seedvr2_path} -> {seedvr2_real}")


def run_command(command, cwd=None, fatal=False):
    print(f"Neo: running command: {' '.join(command)}")
    result = subprocess.run(command, cwd=str(cwd) if cwd else None)
    if result.returncode != 0:
        message = f"Neo warning: command failed with exit code {result.returncode}: {' '.join(command)}"
        if fatal:
            raise RuntimeError(message)
        print(message)
    return result.returncode


def ensure_res4lyf_custom_node():
    install_flag = os.environ.get("INSTALL_RES4LYF", "1").strip().lower()
    if install_flag in {"0", "false", "no", "off"}:
        print("Neo: INSTALL_RES4LYF disabled, skipping RES4LYF install")
        return

    if not COMFY_ROOT.exists():
        print("Neo warning: ComfyUI root missing, cannot install RES4LYF yet.")
        return

    custom_nodes_dir = COMFY_ROOT / "custom_nodes"
    custom_nodes_dir.mkdir(parents=True, exist_ok=True)

    target = custom_nodes_dir / "RES4LYF"
    repo_url = "https://github.com/ClownsharkBatwing/RES4LYF.git"

    print("--------------------------------------")
    print("Neo: ensuring custom node RES4LYF")
    print(f"repo: {repo_url}")
    print(f"path: {target}")
    print("--------------------------------------")

    if (target / ".git").exists():
        run_command(["git", "-C", str(target), "pull", "--ff-only"], fatal=False)
    elif target.exists():
        print(f"Neo warning: {target} exists but is not a git repo. Leaving it untouched.")
    else:
        run_command(["git", "clone", "--depth", "1", repo_url, str(target)], fatal=False)

    requirements = target / "requirements.txt"
    if requirements.exists():
        run_command(
            ["/opt/venv/bin/python", "-m", "pip", "install", "-r", str(requirements)],
            fatal=False,
        )
    else:
        print("Neo: RES4LYF requirements.txt not found, skipping pip install.")



def ensure_hf_tools():
    try:
        import huggingface_hub  # noqa: F401
        print("Neo: huggingface_hub available")
    except Exception:
        print("Neo: installing huggingface_hub")
        subprocess.run(
            ["/opt/venv/bin/python", "-m", "pip", "install", "-U", "huggingface_hub"],
            check=True,
        )


def link_to_other_folders(final_file, folders):
    for folder in folders:
        link_dir = MODEL_ROOT / folder
        link_dir.mkdir(parents=True, exist_ok=True)

        link_path = link_dir / final_file.name

        if link_path.exists() or link_path.is_symlink():
            print(f"Neo: link already exists: {link_path}")
            continue

        try:
            link_path.symlink_to(final_file)
            print(f"Neo: linked {link_path} -> {final_file}")
        except Exception as error:
            print(f"Neo warning: could not symlink {link_path}: {error}")


def hf_download(repo_id, filename, folder, also_link_to=None, output_name=None):
    from huggingface_hub import hf_hub_download

    target_dir = MODEL_ROOT / folder
    target_dir.mkdir(parents=True, exist_ok=True)

    final_name = output_name or Path(filename).name
    final_file = target_dir / final_name

    if final_file.exists() and final_file.stat().st_size > 1024 * 1024:
        print(f"Neo: already exists, skipping: {final_file}")
        if also_link_to:
            link_to_other_folders(final_file, also_link_to)
        return

    print("--------------------------------------")
    print("Neo: downloading Hugging Face file")
    print(f"repo: {repo_id}")
    print(f"file: {filename}")
    print(f"to:   {final_file}")
    print("--------------------------------------")

    tmp_dir = target_dir / "_hf_tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    downloaded_path = hf_hub_download(
        repo_id=repo_id,
        filename=filename,
        token=HF_TOKEN,
        local_dir=str(tmp_dir),
    )

    downloaded_path = Path(downloaded_path)

    if not downloaded_path.exists():
        raise RuntimeError(f"Neo error: download path missing: {downloaded_path}")

    if final_file.exists():
        final_file.unlink()

    shutil.move(str(downloaded_path), str(final_file))
    shutil.rmtree(tmp_dir, ignore_errors=True)

    print(f"Neo: downloaded {final_file}")
    print(f"Neo: size GB = {final_file.stat().st_size / 1024 / 1024 / 1024:.2f}")

    if also_link_to:
        link_to_other_folders(final_file, also_link_to)


def run_profile():
    if MODEL_PROFILE not in PROFILES:
        print(f"Neo error: unknown MODEL_PROFILE={MODEL_PROFILE}")
        print(f"Neo available profiles: {list(PROFILES.keys())}")
        raise SystemExit(1)

    items = PROFILES[MODEL_PROFILE]

    if not items:
        print(f"Neo: no model downloads for profile: {MODEL_PROFILE}")
        return

    ensure_hf_tools()

    for item in items:
        hf_download(
            repo_id=item["repo_id"],
            filename=item["filename"],
            folder=item["folder"],
            also_link_to=item.get("also_link_to"),
            output_name=item.get("output_name"),
        )


ensure_base()
run_profile()

print("Neo: model profile step complete.")
