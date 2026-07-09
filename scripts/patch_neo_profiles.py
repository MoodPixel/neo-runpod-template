#!/usr/bin/env python3
"""Patch Neo Studio backend profiles for a Linux/RunPod runtime.

This script is intentionally a runtime patcher. It does not edit the Neo source
checkout templates. It writes patched copies and explicit RunPod overrides under:

    /workspace/Neo_Studio_V2/neo_data/settings/backends

Why this exists:
- The desktop Neo repo can keep Windows/local-portable defaults.
- The RunPod template needs Linux-safe HTTP backend defaults.
- Runtime state belongs in neo_data, not in source-controlled files.
"""

from __future__ import annotations

import json
import os
import shutil
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

NEO_ROOT = Path(os.environ.get("NEO_ROOT", "/workspace/Neo_Studio_V2")).resolve()
RUNTIME_BACKENDS = NEO_ROOT / "neo_data" / "settings" / "backends"

COMFY_PORT = os.environ.get("COMFY_PORT", "8188")
KOBOLD_PORT = os.environ.get("KOBOLD_PORT", "5001")

COMFY_BASE_URL = os.environ.get("NEO_COMFY_BASE_URL", f"http://127.0.0.1:{COMFY_PORT}")
KOBOLD_BASE_URL = os.environ.get("NEO_KOBOLD_BASE_URL", f"http://127.0.0.1:{KOBOLD_PORT}")

IMAGE_PROFILE_ID = os.environ.get("NEO_IMAGE_PROFILE_ID", "comfyui_local")
VIDEO_PROFILE_ID = os.environ.get("NEO_VIDEO_PROFILE_ID", "video.comfyui")
TEXT_PROFILE_ID = os.environ.get("NEO_TEXT_PROFILE_ID", "local_koboldcpp_text")

DEFAULTS = {
    "image": IMAGE_PROFILE_ID,
    "video": VIDEO_PROFILE_ID,
    "text": TEXT_PROFILE_ID,
    "assistant": TEXT_PROFILE_ID,
    "prompt_captioning": TEXT_PROFILE_ID,
    "roleplay": TEXT_PROFILE_ID,
}

SKIP_DIRS = {
    ".git",
    ".venv",
    "venv",
    "__pycache__",
    "node_modules",
    "neo_data",
    "outputs",
    "inputs",
    "models",
    "checkpoints",
}

BACKEND_HINTS = (
    "backend",
    "backends",
    "profile",
    "profiles",
    "provider",
    "providers",
)


def log(message: str) -> None:
    print(f"[patch-neo-profiles] {message}", flush=True)


def load_yaml_support():
    try:
        import yaml  # type: ignore

        return yaml
    except Exception:
        return None


def is_candidate(path: Path) -> bool:
    if path.suffix.lower() not in {".json", ".yaml", ".yml"}:
        return False
    lowered = "/".join(part.lower() for part in path.parts)
    return any(hint in lowered for hint in BACKEND_HINTS)


def iter_candidate_files(root: Path) -> list[Path]:
    if not root.exists():
        return []

    results: list[Path] = []
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        base = Path(current)
        for filename in files:
            path = base / filename
            if is_candidate(path):
                results.append(path)
    return sorted(results)


def profile_identity(value: Any) -> str:
    if not isinstance(value, dict):
        return ""
    pieces: list[str] = []
    for key in ("id", "name", "key", "label", "title", "provider", "provider_id", "surface", "kind"):
        item = value.get(key)
        if isinstance(item, str):
            pieces.append(item.lower())
    return " ".join(pieces)


def looks_like_comfy_profile(value: Any) -> bool:
    ident = profile_identity(value)
    base = str(value.get("base_url", "")).lower() if isinstance(value, dict) else ""
    return "comfy" in ident or ":8188" in base


def looks_like_kobold_profile(value: Any) -> bool:
    ident = profile_identity(value)
    base = str(value.get("base_url", "")).lower() if isinstance(value, dict) else ""
    return "kobold" in ident or "koboldcpp" in ident or ":5001" in base


def strip_windows_portable_launcher(value: dict[str, Any]) -> None:
    launch = value.get("launch_command")
    if isinstance(launch, str) and (".bat" in launch.lower() or "portable" in launch.lower()):
        value["launch_command"] = ""
        value["launch_note"] = "Disabled by RunPod runtime patch; services are managed by /start.sh."

    launcher_keys = ["working_dir", "portable_path", "portable_root", "windows_path"]
    for key in launcher_keys:
        if key in value and isinstance(value[key], str):
            value[key] = ""

    if str(value.get("kind", "")).lower() in {"portable_path", "windows_portable", "desktop_portable"}:
        value["kind"] = "local_http"


def patch_profile_dict(value: dict[str, Any]) -> bool:
    changed = False

    if looks_like_comfy_profile(value):
        for key in ("base_url", "url", "api_base", "endpoint"):
            if key in value and value[key] != COMFY_BASE_URL:
                value[key] = COMFY_BASE_URL
                changed = True
        if "base_url" not in value:
            value["base_url"] = COMFY_BASE_URL
            changed = True
        if value.get("kind") in {"portable_path", "windows_portable", "desktop_portable"}:
            value["kind"] = "local_http"
            changed = True
        before = deepcopy(value)
        strip_windows_portable_launcher(value)
        changed = changed or before != value

    if looks_like_kobold_profile(value):
        for key in ("base_url", "url", "api_base", "endpoint"):
            if key in value and value[key] != KOBOLD_BASE_URL:
                value[key] = KOBOLD_BASE_URL
                changed = True
        if "base_url" not in value:
            value["base_url"] = KOBOLD_BASE_URL
            changed = True
        if "chat_endpoint" in value and value["chat_endpoint"] != "/v1/chat/completions":
            value["chat_endpoint"] = "/v1/chat/completions"
            changed = True
        if "models_endpoint" in value and value["models_endpoint"] != "/v1/models":
            value["models_endpoint"] = "/v1/models"
            changed = True

    return changed


def runpod_comfy_image_profile() -> dict[str, Any]:
    return {
        "id": IMAGE_PROFILE_ID,
        "label": "ComfyUI Image (RunPod)",
        "provider": "comfyui",
        "kind": "local_http",
        "base_url": COMFY_BASE_URL,
        "enabled": True,
        "default": True,
        "auth": {"type": "none"},
        "capabilities": ["image_generation", "video_generation", "live_preview", "progress"],
        "health_endpoint": "/system_stats",
        "object_info_endpoint": "/object_info",
        "notes": "Managed by RunPod runtime patch. ComfyUI is started by /start.sh.",
    }


def runpod_comfy_video_profile() -> dict[str, Any]:
    return {
        "id": VIDEO_PROFILE_ID,
        "label": "ComfyUI Video (RunPod)",
        "provider": "comfyui",
        "kind": "local_http",
        "base_url": COMFY_BASE_URL,
        "enabled": True,
        "default": True,
        "auth": {"type": "none"},
        "capabilities": ["video_generation", "image_generation", "live_preview", "progress"],
        "health_endpoint": "/system_stats",
        "object_info_endpoint": "/object_info",
        "notes": "Linux/RunPod replacement for Windows portable ComfyUI video profiles.",
    }


def runpod_kobold_profile() -> dict[str, Any]:
    return {
        "id": TEXT_PROFILE_ID,
        "label": "KoboldCPP Text (RunPod)",
        "provider": "koboldcpp",
        "kind": "local_http",
        "base_url": KOBOLD_BASE_URL,
        "enabled": os.environ.get("START_KOBOLD", "0") == "1",
        "default": True,
        "auth": {"type": "none"},
        "capabilities": ["text", "chat", "assistant", "prompt_captioning", "roleplay"],
        "health_endpoint": "/v1/models",
        "chat_endpoint": "/v1/chat/completions",
        "timeout_seconds": int(os.environ.get("KOBOLD_TIMEOUT_SECONDS", "300")),
        "notes": "Optional. Enable START_KOBOLD=1 and provide KOBOLD_MODEL to run locally.",
    }


def ensure_profiles_container(root: dict[str, Any]) -> bool:
    changed = False

    defaults = root.get("defaults")
    if not isinstance(defaults, dict):
        root["defaults"] = {}
        defaults = root["defaults"]
        changed = True

    for surface, profile_id in DEFAULTS.items():
        if defaults.get(surface) != profile_id:
            defaults[surface] = profile_id
            changed = True

    profiles = root.get("profiles")
    if isinstance(profiles, dict):
        for profile_id, profile in {
            IMAGE_PROFILE_ID: runpod_comfy_image_profile(),
            VIDEO_PROFILE_ID: runpod_comfy_video_profile(),
            TEXT_PROFILE_ID: runpod_kobold_profile(),
        }.items():
            current = profiles.get(profile_id)
            if isinstance(current, dict):
                before = deepcopy(current)
                current.update({k: v for k, v in profile.items() if k not in {"label", "notes"} or k not in current})
                strip_windows_portable_launcher(current)
                changed = changed or before != current
            else:
                profiles[profile_id] = profile
                changed = True
    elif isinstance(profiles, list):
        existing_ids = {p.get("id") for p in profiles if isinstance(p, dict)}
        for profile in (runpod_comfy_image_profile(), runpod_comfy_video_profile(), runpod_kobold_profile()):
            if profile["id"] not in existing_ids:
                profiles.append(profile)
                changed = True
    else:
        root["profiles"] = {
            IMAGE_PROFILE_ID: runpod_comfy_image_profile(),
            VIDEO_PROFILE_ID: runpod_comfy_video_profile(),
            TEXT_PROFILE_ID: runpod_kobold_profile(),
        }
        changed = True

    root["runpod_runtime"] = {
        "patched": True,
        "patched_at": datetime.now(timezone.utc).isoformat(),
        "comfy_base_url": COMFY_BASE_URL,
        "kobold_base_url": KOBOLD_BASE_URL,
        "managed_by": "MoodPixel/neo-runpod-template scripts/patch_neo_profiles.py",
    }
    changed = True
    return changed


def patch_tree(value: Any) -> bool:
    changed = False
    if isinstance(value, dict):
        changed = patch_profile_dict(value) or changed
        if "defaults" in value or "profiles" in value:
            changed = ensure_profiles_container(value) or changed
        for child in value.values():
            changed = patch_tree(child) or changed
    elif isinstance(value, list):
        for child in value:
            changed = patch_tree(child) or changed
    return changed


def load_structured(path: Path) -> tuple[Any, str] | None:
    suffix = path.suffix.lower()
    try:
        if suffix == ".json":
            return json.loads(path.read_text(encoding="utf-8")), "json"
        if suffix in {".yaml", ".yml"}:
            yaml = load_yaml_support()
            if yaml is None:
                log(f"Skipping YAML without PyYAML available: {path}")
                return None
            return yaml.safe_load(path.read_text(encoding="utf-8")), "yaml"
    except Exception as exc:
        log(f"Could not parse {path}: {exc}")
        return None
    return None


def write_structured(path: Path, value: Any, fmt: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if fmt == "json":
        path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        return
    yaml = load_yaml_support()
    if yaml is None:
        raise RuntimeError("PyYAML missing while writing YAML")
    path.write_text(yaml.safe_dump(value, sort_keys=False, allow_unicode=True), encoding="utf-8")


def patch_source_copy(source: Path) -> bool:
    rel = source.relative_to(NEO_ROOT)
    target = RUNTIME_BACKENDS / "patched" / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

    loaded = load_structured(target)
    if loaded is None:
        return False
    data, fmt = loaded
    if not isinstance(data, (dict, list)):
        return False
    changed = patch_tree(data)
    if changed:
        write_structured(target, data, fmt)
        log(f"Patched runtime copy: {target}")
    return changed


def write_explicit_override() -> Path:
    override = {
        "schema": "neo.runpod.backend_profiles.v1",
        "defaults": DEFAULTS,
        "profiles": {
            IMAGE_PROFILE_ID: runpod_comfy_image_profile(),
            VIDEO_PROFILE_ID: runpod_comfy_video_profile(),
            TEXT_PROFILE_ID: runpod_kobold_profile(),
        },
        "providers": {
            "comfyui": {
                "base_url": COMFY_BASE_URL,
                "health_endpoint": "/system_stats",
                "object_info_endpoint": "/object_info",
                "preview": "websocket",
            },
            "koboldcpp": {
                "base_url": KOBOLD_BASE_URL,
                "health_endpoint": "/v1/models",
                "chat_endpoint": "/v1/chat/completions",
                "enabled": os.environ.get("START_KOBOLD", "0") == "1",
            },
        },
        "notes": [
            "Runtime override generated by neo-runpod-template.",
            "Do not commit this file back into Neo_Studio_V2 source.",
            "The pod template manages ComfyUI/KoboldCPP processes via /start.sh.",
        ],
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    target = RUNTIME_BACKENDS / "runpod_backend_profiles.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(override, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    log(f"Wrote explicit RunPod override: {target}")
    return target


def write_env_file() -> Path:
    target = RUNTIME_BACKENDS / "runpod_backend.env"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        "\n".join(
            [
                f"NEO_BACKEND_MODE=runpod",
                f"NEO_COMFY_BASE_URL={COMFY_BASE_URL}",
                f"NEO_KOBOLD_BASE_URL={KOBOLD_BASE_URL}",
                f"NEO_IMAGE_PROFILE_ID={IMAGE_PROFILE_ID}",
                f"NEO_VIDEO_PROFILE_ID={VIDEO_PROFILE_ID}",
                f"NEO_TEXT_PROFILE_ID={TEXT_PROFILE_ID}",
                "",
            ]
        ),
        encoding="utf-8",
    )
    log(f"Wrote runtime env hint: {target}")
    return target


def main() -> int:
    if not NEO_ROOT.exists():
        log(f"Neo root does not exist yet: {NEO_ROOT}")
        return 0

    RUNTIME_BACKENDS.mkdir(parents=True, exist_ok=True)
    log(f"Neo root: {NEO_ROOT}")
    log(f"Runtime backend dir: {RUNTIME_BACKENDS}")
    log(f"Comfy URL: {COMFY_BASE_URL}")
    log(f"Kobold URL: {KOBOLD_BASE_URL}")

    candidates = iter_candidate_files(NEO_ROOT)
    patched_count = 0
    for source in candidates:
        try:
            if patch_source_copy(source):
                patched_count += 1
        except Exception as exc:
            log(f"Failed to patch {source}: {exc}")

    write_explicit_override()
    write_env_file()
    log(f"Runtime backend profile patch complete. Patched source copies: {patched_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
