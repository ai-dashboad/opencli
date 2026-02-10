"""Local Models API — list, env check, setup, download, delete.

Ported from unified_api_server.dart local model handlers.
Instead of managing a separate LocalModelManager, this directly checks
the local-inference/ directory for environment and model state.
"""

import os
import json
import sys
from pathlib import Path
from typing import Any

from fastapi import APIRouter

from opencli_daemon.utils.subprocess_runner import run_command

router = APIRouter(prefix="/api/v1", tags=["local-models"])

_PROJECT_ROOT = Path(__file__).resolve().parents[2]  # daemon-py/
_INFERENCE_DIR = _PROJECT_ROOT.parent / "local-inference"
_MODELS_DIR = Path(os.environ.get("HOME", ".")) / ".opencli" / "models"
_VENV_DIR = _INFERENCE_DIR / ".venv"
_PYTHON = str(_VENV_DIR / "bin" / "python3")

# Model definitions (mirrors local_model_manager.dart)
_MODELS = [
    {"id": "waifu_diffusion", "name": "Waifu Diffusion", "type": "image", "size_gb": 2.0,
     "hf_repo": "hakurei/waifu-diffusion", "description": "Anime-style SD 1.4 fine-tune"},
    {"id": "animagine_xl", "name": "Animagine XL 3.1", "type": "image", "size_gb": 6.5,
     "hf_repo": "cagliostrolab/animagine-xl-3.1", "description": "High-quality anime SDXL"},
    {"id": "pony_diffusion", "name": "Pony Diffusion V6 XL", "type": "image", "size_gb": 6.5,
     "hf_repo": "AstraliteHeart/pony-diffusion-v6", "description": "Versatile anime SDXL"},
    {"id": "animatediff_v3", "name": "AnimateDiff V3", "type": "video", "size_gb": 2.8,
     "hf_repo": "guoyww/animatediff-motion-adapter-v1-5-3", "description": "Motion adapter for SD 1.5"},
    {"id": "svd", "name": "Stable Video Diffusion", "type": "video", "size_gb": 4.0,
     "hf_repo": "stabilityai/stable-video-diffusion-img2vid-xt", "description": "Image-to-video generation"},
    {"id": "animegan_v3", "name": "AnimeGAN v3", "type": "style", "size_gb": 0.1,
     "hf_repo": "bryandlee/animegan2-pytorch", "description": "Photo to anime style transfer"},
    {"id": "controlnet_lineart", "name": "ControlNet Lineart", "type": "controlnet", "size_gb": 1.4,
     "hf_repo": "lllyasviel/control_v11p_sd15_lineart", "description": "Lineart control for anime"},
    {"id": "controlnet_openpose", "name": "ControlNet OpenPose", "type": "controlnet", "size_gb": 1.4,
     "hf_repo": "lllyasviel/control_v11p_sd15_openpose", "description": "Pose control"},
    {"id": "controlnet_depth", "name": "ControlNet Depth", "type": "controlnet", "size_gb": 1.4,
     "hf_repo": "lllyasviel/control_v11f1p_sd15_depth", "description": "Depth control"},
    {"id": "ip_adapter_face", "name": "IP-Adapter FaceID", "type": "adapter", "size_gb": 1.5,
     "hf_repo": "h94/IP-Adapter-FaceID", "description": "Face consistency adapter"},
]


def _model_downloaded(model_id: str) -> bool:
    return (_MODELS_DIR / model_id).exists()


@router.get("/local-models")
async def list_models() -> dict:
    models = []
    for m in _MODELS:
        models.append({
            **m,
            "downloaded": _model_downloaded(m["id"]),
            "path": str(_MODELS_DIR / m["id"]),
        })
    return {"models": models, "available": _VENV_DIR.exists()}


@router.get("/local-models/environment")
async def check_environment() -> dict:
    venv_exists = _VENV_DIR.exists()
    if not venv_exists:
        return {
            "ok": False,
            "python_version": "not configured",
            "device": "unknown",
            "missing_packages": ["venv not created — run setup"],
            "venv_exists": False,
        }

    try:
        stdout, stderr, rc = await run_command(
            [_PYTHON, "-c",
             "import sys, torch; "
             "print(f'{sys.version.split()[0]}|||'+"
             "f'{\"mps\" if torch.backends.mps.is_available() else \"cpu\"}')"],
            timeout=15.0,
        )
        if rc != 0:
            return {"ok": False, "python_version": "error", "device": "unknown",
                    "missing_packages": [stderr.strip()], "venv_exists": True}

        parts = stdout.strip().split("|||")
        py_ver = parts[0] if parts else "unknown"
        device = parts[1] if len(parts) > 1 else "cpu"

        # Check packages
        missing = []
        for pkg in ["torch", "diffusers", "transformers", "accelerate"]:
            check_stdout, _, check_rc = await run_command(
                [_PYTHON, "-c", f"import {pkg}"], timeout=10.0
            )
            if check_rc != 0:
                missing.append(pkg)

        return {
            "ok": len(missing) == 0,
            "python_version": py_ver,
            "device": device,
            "missing_packages": missing,
            "venv_exists": True,
        }
    except Exception as e:
        return {"ok": False, "python_version": "error", "device": "unknown",
                "missing_packages": [str(e)], "venv_exists": venv_exists}


@router.post("/local-models/setup")
async def setup_environment() -> dict:
    setup_script = _INFERENCE_DIR / "setup.sh"
    if not setup_script.exists():
        return {"success": False, "error": "setup.sh not found"}
    try:
        stdout, stderr, rc = await run_command(
            ["bash", str(setup_script)],
            timeout=600.0,
            cwd=str(_INFERENCE_DIR),
        )
        return {"success": rc == 0, "output": stdout[-2000:], "error": stderr[-1000:] if rc != 0 else ""}
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.post("/local-models/{model_id}/download")
async def download_model(model_id: str) -> dict:
    model = next((m for m in _MODELS if m["id"] == model_id), None)
    if not model:
        return {"success": False, "error": f"Unknown model: {model_id}"}

    dest = _MODELS_DIR / model_id
    dest.mkdir(parents=True, exist_ok=True)

    try:
        stdout, stderr, rc = await run_command(
            [_PYTHON, "-c",
             f"from huggingface_hub import snapshot_download; "
             f"snapshot_download('{model['hf_repo']}', local_dir='{dest}')"],
            timeout=1800.0,
        )
        return {"success": rc == 0, "path": str(dest), "error": stderr[-500:] if rc != 0 else ""}
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.delete("/local-models/{model_id}")
async def delete_model(model_id: str) -> dict:
    import shutil
    dest = _MODELS_DIR / model_id
    if dest.exists():
        shutil.rmtree(dest)
        return {"success": True, "message": f"Deleted {model_id}"}
    return {"success": False, "error": f"Model not found: {model_id}"}
