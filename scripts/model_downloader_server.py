#!/usr/bin/env python3
"""Small on-demand model downloader for the Neo RunPod template.

This server is intentionally template-owned. It does not import or modify Neo Studio.
It writes only under /workspace/neo-models and keeps ComfyUI linked through
extra_model_paths.yaml.
"""

from __future__ import annotations

import html
import json
import mimetypes
import os
import re
import shutil
import threading
import time
import uuid
from dataclasses import asdict, dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import parse_qs, unquote, urlparse
from urllib.request import Request, urlopen

MODEL_ROOT = Path(os.environ.get("MODEL_ROOT", "/workspace/neo-models")).resolve()
COMFY_ROOT = Path(os.environ.get("COMFY_ROOT", "/workspace/ComfyUI")).resolve()
HOST = os.environ.get("MODEL_DOWNLOADER_HOST", "0.0.0.0")
PORT = int(os.environ.get("MODEL_DOWNLOADER_PORT", "7861"))
TOKEN = os.environ.get("MODEL_DOWNLOADER_TOKEN", "")
CATEGORY_MANIFEST = Path(os.environ.get("MODEL_CATEGORY_MANIFEST", "/opt/neo-runpod/config/model-download-categories.tsv"))
STATUS_FILE = Path(os.environ.get("MODEL_DOWNLOADER_STATUS_FILE", "/workspace/logs/model_downloader_jobs.jsonl"))
ALLOW_ANY_EXTENSION = os.environ.get("MODEL_DOWNLOADER_ALLOW_ANY_EXTENSION", "0") == "1"
DEFAULT_OVERWRITE = os.environ.get("MODEL_DOWNLOADER_OVERWRITE", "0") == "1"
CHUNK_SIZE = int(os.environ.get("MODEL_DOWNLOADER_CHUNK_SIZE", str(1024 * 1024)))

SAFE_EXTENSIONS = {
    ".safetensors", ".ckpt", ".pt", ".pth", ".bin", ".gguf", ".onnx",
    ".json", ".yaml", ".yml", ".txt", ".zip", ".tar", ".gz", ".7z",
}

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


@dataclass
class Category:
    key: str
    label: str
    relative_path: str
    notes: str = ""

    @property
    def target_dir(self) -> Path:
        return (MODEL_ROOT / self.relative_path).resolve()


@dataclass
class Job:
    id: str
    url: str
    category: str
    target: str
    filename: str
    status: str = "queued"
    bytes_downloaded: int = 0
    total_bytes: Optional[int] = None
    error: str = ""
    created_at: float = 0.0
    updated_at: float = 0.0


jobs: Dict[str, Job] = {}
jobs_lock = threading.Lock()


def log_status(job: Job) -> None:
    STATUS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with STATUS_FILE.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(asdict(job), ensure_ascii=False) + "\n")


def load_categories() -> Dict[str, Category]:
    default = {
        "checkpoints": Category("checkpoints", "Checkpoints / SDXL / AIO", "ckpt_bank", "Main checkpoint bank."),
        "diffusion_models": Category("diffusion_models", "Diffusion Models", "diffusion_models", "UNet/diffusion model files."),
        "unet": Category("unet", "UNet", "unet", "Alternate UNet folder."),
        "vae": Category("vae", "VAE", "vae", "VAE model files."),
        "loras": Category("loras", "LoRA / LyCORIS", "loras", "LoRA files."),
        "controlnet": Category("controlnet", "ControlNet", "controlnet", "ControlNet models."),
        "text_gguf": Category("text_gguf", "Text GGUF Models", "text", "KoboldCPP GGUF files."),
        "other": Category("other", "Other / Manual", "other", "Fallback folder."),
    }
    if not CATEGORY_MANIFEST.exists():
        return default

    out: Dict[str, Category] = {}
    for raw in CATEGORY_MANIFEST.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = raw.split("\t")
        if len(parts) < 3:
            continue
        key, label, rel = [p.strip() for p in parts[:3]]
        notes = parts[3].strip() if len(parts) > 3 else ""
        if key and rel:
            out[key] = Category(key, label or key, rel, notes)
    return out or default


def ensure_paths() -> None:
    MODEL_ROOT.mkdir(parents=True, exist_ok=True)
    for category in CATEGORIES.values():
        target = category.target_dir
        if not str(target).startswith(str(MODEL_ROOT)):
            raise RuntimeError(f"Unsafe category path: {category.key} -> {target}")
        target.mkdir(parents=True, exist_ok=True)

    if COMFY_ROOT.exists():
        (COMFY_ROOT / "extra_model_paths.yaml").write_text(YAML_TEXT, encoding="utf-8")
        seedvr2_src = MODEL_ROOT / "SEEDVR2"
        seedvr2_src.mkdir(parents=True, exist_ok=True)
        comfy_models = COMFY_ROOT / "models"
        comfy_models.mkdir(parents=True, exist_ok=True)
        seedvr2_link = comfy_models / "SEEDVR2"
        if not seedvr2_link.exists() and not seedvr2_link.is_symlink():
            try:
                seedvr2_link.symlink_to(seedvr2_src, target_is_directory=True)
            except Exception:
                pass


def sanitize_filename(name: str) -> str:
    name = unquote(name or "").split("?")[0].split("#")[0].strip()
    name = name.replace("\\", "/").split("/")[-1]
    name = re.sub(r"[^A-Za-z0-9._()\- +]", "_", name)
    name = name.strip(" ._")
    if not name:
        name = f"model_{int(time.time())}.safetensors"
    return name[:180]


def filename_from_url(url: str) -> str:
    parsed = urlparse(url)
    name = sanitize_filename(Path(parsed.path).name)
    if name and "." in name:
        return name
    qs = parse_qs(parsed.query)
    for key in ("filename", "file", "name"):
        if qs.get(key):
            return sanitize_filename(qs[key][0])
    return name or f"download_{int(time.time())}.safetensors"


def filename_from_headers(headers, fallback: str) -> str:
    cd = headers.get("Content-Disposition", "")
    match = re.search(r'filename\*?=(?:UTF-8\'\')?"?([^";]+)', cd, flags=re.IGNORECASE)
    if match:
        return sanitize_filename(match.group(1))
    return fallback


def validate_filename(filename: str) -> None:
    suffix = Path(filename).suffix.lower()
    if ALLOW_ANY_EXTENSION:
        return
    if suffix not in SAFE_EXTENSIONS:
        raise ValueError(
            f"Blocked extension '{suffix or '<none>'}'. Rename with a known model extension or set MODEL_DOWNLOADER_ALLOW_ANY_EXTENSION=1."
        )


def build_headers(url: str) -> Dict[str, str]:
    headers = {"User-Agent": "Neo-RunPod-Model-Downloader/1.0"}
    host = urlparse(url).netloc.lower()
    if "huggingface.co" in host and os.environ.get("HF_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['HF_TOKEN']}"
    if "civitai.com" in host:
        token = os.environ.get("CIVITAI_TOKEN") or os.environ.get("CIVITAI_API_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"
    extra = os.environ.get("MODEL_DOWNLOADER_AUTH_HEADER", "").strip()
    if extra and ":" in extra:
        k, v = extra.split(":", 1)
        headers[k.strip()] = v.strip()
    return headers


def download_worker(job_id: str, overwrite: bool = False) -> None:
    with jobs_lock:
        job = jobs[job_id]
        job.status = "downloading"
        job.updated_at = time.time()
        log_status(job)

    target = Path(job.target)
    tmp = target.with_suffix(target.suffix + ".part")

    try:
        if target.exists() and target.stat().st_size > 0 and not overwrite:
            with jobs_lock:
                job.status = "exists"
                job.bytes_downloaded = target.stat().st_size
                job.total_bytes = target.stat().st_size
                job.updated_at = time.time()
                log_status(job)
            return

        req = Request(job.url, headers=build_headers(job.url))
        with urlopen(req, timeout=60) as response:
            total = response.headers.get("Content-Length")
            final_name = filename_from_headers(response.headers, job.filename)
            if final_name != job.filename and not target.exists():
                validate_filename(final_name)
                target = target.parent / final_name
                tmp = target.with_suffix(target.suffix + ".part")
                with jobs_lock:
                    job.filename = final_name
                    job.target = str(target)
            with jobs_lock:
                job.total_bytes = int(total) if total and total.isdigit() else None
                job.updated_at = time.time()
                log_status(job)

            target.parent.mkdir(parents=True, exist_ok=True)
            with tmp.open("wb") as handle:
                while True:
                    chunk = response.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    handle.write(chunk)
                    with jobs_lock:
                        job.bytes_downloaded += len(chunk)
                        job.updated_at = time.time()
            tmp.replace(target)

        with jobs_lock:
            job.status = "done"
            job.bytes_downloaded = target.stat().st_size
            job.updated_at = time.time()
            log_status(job)
    except Exception as exc:
        try:
            if tmp.exists():
                tmp.unlink()
        except Exception:
            pass
        with jobs_lock:
            job.status = "error"
            job.error = str(exc)
            job.updated_at = time.time()
            log_status(job)


def require_auth(handler: BaseHTTPRequestHandler) -> bool:
    if not TOKEN:
        return True
    supplied = handler.headers.get("X-Model-Downloader-Token", "")
    if supplied == TOKEN:
        return True
    query = parse_qs(urlparse(handler.path).query)
    if query.get("token", [""])[0] == TOKEN:
        return True
    handler.send_error(HTTPStatus.UNAUTHORIZED, "MODEL_DOWNLOADER_TOKEN required")
    return False


def read_body(handler: BaseHTTPRequestHandler) -> Dict[str, str]:
    length = int(handler.headers.get("Content-Length", "0") or "0")
    raw = handler.rfile.read(length) if length else b""
    ctype = handler.headers.get("Content-Type", "")
    if "application/json" in ctype:
        data = json.loads(raw.decode("utf-8") or "{}")
        return {str(k): str(v) for k, v in data.items()}
    form = parse_qs(raw.decode("utf-8"))
    return {k: v[0] for k, v in form.items()}


def json_response(handler: BaseHTTPRequestHandler, payload, status: int = 200) -> None:
    body = json.dumps(payload, indent=2, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def html_page() -> bytes:
    options = "\n".join(
        f'<option value="{html.escape(c.key)}">{html.escape(c.label)} → {html.escape(str(c.target_dir))}</option>'
        for c in CATEGORIES.values()
    )
    auth_note = "Token required" if TOKEN else "No token set. Expose this port only when you trust the session."
    page = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Neo Model Downloader</title>
<style>
body{{font-family:system-ui,Segoe UI,Arial;margin:32px;background:#111;color:#eee}} .card{{max-width:980px;background:#1b1b1f;padding:24px;border-radius:16px;box-shadow:0 10px 30px #0008}}
input,select,button{{width:100%;padding:12px;margin:8px 0;border-radius:10px;border:1px solid #444;background:#111;color:#eee}} button{{background:#3657ff;border:0;font-weight:700;cursor:pointer}}
small,pre{{color:#aaa}} table{{width:100%;border-collapse:collapse;margin-top:20px}} td,th{{border-bottom:1px solid #333;padding:8px;text-align:left;font-size:14px}}
.badge{{display:inline-block;padding:4px 8px;border-radius:999px;background:#333}}
</style></head><body><div class="card">
<h1>Neo Model Downloader</h1>
<p>Downloads selected model files into <code>{html.escape(str(MODEL_ROOT))}</code>. Comfy path linking is refreshed automatically.</p>
<p><span class="badge">Port {PORT}</span> <span class="badge">{html.escape(auth_note)}</span></p>
<label>Model category</label><select id="category">{options}</select>
<label>Model URL</label><input id="url" placeholder="Hugging Face, CivitAI, GitHub release, or direct file URL">
<label>Optional filename override</label><input id="filename" placeholder="leave empty to infer from URL/headers">
<label>Token, only if MODEL_DOWNLOADER_TOKEN is set</label><input id="token" placeholder="optional UI token">
<label><input id="overwrite" type="checkbox" style="width:auto"> overwrite if file exists</label>
<button onclick="startDownload()">Download</button>
<pre id="result"></pre>
<h2>Jobs</h2><button onclick="loadJobs()">Refresh jobs</button><table><thead><tr><th>Status</th><th>File</th><th>Progress</th><th>Error</th></tr></thead><tbody id="jobs"></tbody></table>
</div><script>
async function startDownload(){{
  const payload={{category:category.value,url:url.value,filename:filename.value,overwrite:overwrite.checked?'1':'0'}};
  const headers={{'Content-Type':'application/json'}}; if(token.value) headers['X-Model-Downloader-Token']=token.value;
  const r=await fetch('/api/download',{{method:'POST',headers,body:JSON.stringify(payload)}}); result.textContent=await r.text(); loadJobs();
}}
async function loadJobs(){{
  const h={{}}; if(token.value) h['X-Model-Downloader-Token']=token.value;
  const r=await fetch('/api/jobs',{{headers:h}}); const data=await r.json();
  jobs.innerHTML=data.jobs.map(j=>`<tr><td>${{j.status}}</td><td>${{j.filename}}<br><small>${{j.target}}</small></td><td>${{fmt(j.bytes_downloaded)}} / ${{j.total_bytes?fmt(j.total_bytes):'?'}}</td><td>${{j.error||''}}</td></tr>`).join('');
}}
function fmt(n){{n=Number(n||0); if(n>1e9)return(n/1e9).toFixed(2)+' GB'; if(n>1e6)return(n/1e6).toFixed(1)+' MB'; return n+' B'}}
setInterval(loadJobs,3000); loadJobs();
</script></body></html>"""
    return page.encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "NeoModelDownloader/1.0"

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            json_response(self, {"ok": True, "model_root": str(MODEL_ROOT), "port": PORT})
            return
        if parsed.path == "/api/categories":
            if not require_auth(self):
                return
            json_response(self, {"categories": [asdict(c) | {"target_dir": str(c.target_dir)} for c in CATEGORIES.values()]})
            return
        if parsed.path == "/api/jobs":
            if not require_auth(self):
                return
            with jobs_lock:
                payload = {"jobs": [asdict(job) for job in jobs.values()]}
            json_response(self, payload)
            return
        if parsed.path == "/":
            body = html_page()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def do_POST(self):
        if urlparse(self.path).path != "/api/download":
            self.send_error(404)
            return
        if not require_auth(self):
            return
        try:
            data = read_body(self)
            url = data.get("url", "").strip()
            category_key = data.get("category", "").strip()
            if not url.startswith(("http://", "https://")):
                raise ValueError("Only http/https URLs are supported")
            if category_key not in CATEGORIES:
                raise ValueError(f"Unknown category: {category_key}")
            category = CATEGORIES[category_key]
            filename = sanitize_filename(data.get("filename") or filename_from_url(url))
            validate_filename(filename)
            target_dir = category.target_dir
            if not str(target_dir).startswith(str(MODEL_ROOT)):
                raise ValueError("Unsafe target category")
            target = target_dir / filename
            job = Job(
                id=str(uuid.uuid4())[:12], url=url, category=category_key,
                target=str(target), filename=filename, created_at=time.time(), updated_at=time.time(),
            )
            with jobs_lock:
                jobs[job.id] = job
                log_status(job)
            overwrite = data.get("overwrite", "1" if DEFAULT_OVERWRITE else "0") in {"1", "true", "yes", "on"}
            thread = threading.Thread(target=download_worker, args=(job.id, overwrite), daemon=True)
            thread.start()
            json_response(self, {"ok": True, "job": asdict(job)})
        except Exception as exc:
            json_response(self, {"ok": False, "error": str(exc)}, status=400)

    def log_message(self, fmt, *args):
        print(f"[model-downloader] {self.address_string()} - {fmt % args}", flush=True)


CATEGORIES = load_categories()


def main() -> int:
    ensure_paths()
    print(f"[model-downloader] model root: {MODEL_ROOT}", flush=True)
    print(f"[model-downloader] category manifest: {CATEGORY_MANIFEST}", flush=True)
    print(f"[model-downloader] listening on {HOST}:{PORT}", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
