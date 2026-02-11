"""Remote inference via HTTP to Colab GPU server.

Mirrors the local_inference.py API but sends requests over HTTP
to a remote FastAPI server (typically running on Colab via FRP tunnel).
"""

import logging
from typing import Any

import httpx

from opencli_daemon.config import load_config, get_nested

logger = logging.getLogger(__name__)

# Timeout: inference can take minutes for video generation
_TIMEOUT = httpx.Timeout(connect=10.0, read=600.0, write=30.0, pool=10.0)


def _get_colab_url() -> str:
    """Get Colab URL from config."""
    config = load_config()
    return get_nested(config, "inference.colab_url", "")


async def is_available() -> bool:
    """Check if remote Colab server is reachable."""
    url = _get_colab_url()
    if not url:
        return False
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0)) as client:
            resp = await client.get(f"{url}/health")
            return resp.status_code == 200
    except Exception:
        return False


async def get_health() -> dict[str, Any]:
    """Get health info from remote server."""
    url = _get_colab_url()
    if not url:
        return {"status": "not_configured"}
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0)) as client:
            resp = await client.get(f"{url}/health")
            return resp.json()
    except Exception as e:
        return {"status": "unreachable", "error": str(e)}


async def run_inference(action: str, params: dict[str, Any]) -> dict[str, Any]:
    """Send inference request to remote Colab server."""
    url = _get_colab_url()
    if not url:
        return {"success": False, "error": "Colab URL not configured. Set inference.colab_url in config."}

    payload = {"action": action, **params}

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.post(f"{url}/infer", json=payload)
            resp.raise_for_status()
            result = resp.json()

            if "success" not in result:
                result["success"] = "error" not in result

            return result

    except httpx.TimeoutException:
        return {"success": False, "error": "Remote inference timed out (10 min limit)"}
    except httpx.HTTPStatusError as e:
        return {"success": False, "error": f"Remote server error: {e.response.status_code}"}
    except Exception as e:
        return {"success": False, "error": f"Remote inference error: {e}"}


async def clear_models() -> dict[str, Any]:
    """Clear all cached models on remote server to free VRAM."""
    url = _get_colab_url()
    if not url:
        return {"success": False, "error": "Colab URL not configured"}
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(10.0)) as client:
            resp = await client.post(f"{url}/clear")
            return resp.json()
    except Exception as e:
        return {"success": False, "error": str(e)}


async def generate_image(
    prompt: str,
    model: str = "animagine_xl",
    width: int = 1024,
    height: int = 1024,
    steps: int = 25,
    **kwargs: Any,
) -> dict[str, Any]:
    """Generate an image using remote GPU."""
    return await run_inference("generate_image", {
        "prompt": prompt,
        "model": model,
        "width": width,
        "height": height,
        "steps": steps,
        **kwargs,
    })


async def generate_video(
    prompt: str = "",
    image_base64: str = "",
    model: str = "animatediff_v3",
    frames: int = 16,
    **kwargs: Any,
) -> dict[str, Any]:
    """Generate a video using remote GPU."""
    action = "generate_video_v3" if model == "animatediff_v3" else "generate_video"
    return await run_inference(action, {
        "prompt": prompt,
        "image_base64": image_base64,
        "model": model,
        "frames": frames,
        **kwargs,
    })


async def style_transfer(
    image_base64: str,
    model: str = "animegan_v3",
    style: str = "face_paint_512_v2",
    **kwargs: Any,
) -> dict[str, Any]:
    """Apply style transfer via remote GPU."""
    return await run_inference("style_transfer", {
        "image_base64": image_base64,
        "model": model,
        "style": style,
        **kwargs,
    })


async def controlnet_video(
    reference_image_base64: str,
    prompt: str,
    control_type: str = "lineart_anime",
    **kwargs: Any,
) -> dict[str, Any]:
    """Generate ControlNet video via remote GPU."""
    return await run_inference("generate_controlnet_video", {
        "reference_image_base64": reference_image_base64,
        "prompt": prompt,
        "control_type": control_type,
        **kwargs,
    })


async def extract_control(
    image_base64: str,
    control_type: str = "lineart_anime",
    **kwargs: Any,
) -> dict[str, Any]:
    """Extract control map via remote GPU."""
    return await run_inference("extract_control", {
        "image_base64": image_base64,
        "control_type": control_type,
        **kwargs,
    })
