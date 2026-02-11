"""Inference backend status API.

Exposes /api/v1/inference/status to check Colab GPU connection
and local inference availability.
"""

from fastapi import APIRouter

from opencli_daemon.config import load_config, get_nested
from opencli_daemon.domains.media_creation import local_inference, remote_inference

router = APIRouter(prefix="/api/v1/inference", tags=["inference"])


@router.get("/status")
async def inference_status():
    """Check inference backend status — local and remote."""
    config = load_config()
    colab_url = get_nested(config, "inference.colab_url", "")
    backend = get_nested(config, "inference.backend", "auto")

    colab_available = False
    colab_info = {}
    if colab_url:
        health = await remote_inference.get_health()
        colab_available = health.get("status") == "ok"
        colab_info = health

    return {
        "backend": backend,
        "colab_url": colab_url,
        "colab_available": colab_available,
        "colab_info": colab_info,
        "local_available": local_inference._is_available(),
    }
