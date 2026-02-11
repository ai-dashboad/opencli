"""Local inference via subprocess.

Spawns local-inference/.venv/bin/python infer.py with JSON on stdin,
reads JSON result from stdout. This approach avoids venv dependency
conflicts — the daemon venv doesn't need torch/diffusers.

Stdout and stderr are read concurrently to prevent pipe deadlock
(see MEMORY.md: Python Subprocess Deadlock).
"""

import asyncio
import json
import logging
import os
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

_INFERENCE_DIR = Path(__file__).resolve().parents[4] / "local-inference"
_INFER_SCRIPT = _INFERENCE_DIR / "infer.py"
_VENV_PYTHON = _INFERENCE_DIR / ".venv" / "bin" / "python"
_MODELS_DIR = Path(os.environ.get("HOME", ".")) / ".opencli" / "models"


def _is_available() -> bool:
    """Check if local inference environment is set up."""
    return _VENV_PYTHON.exists() and _INFER_SCRIPT.exists()


async def run_inference(action: str, params: dict[str, Any]) -> dict[str, Any]:
    """Run an inference action via subprocess (non-blocking).

    Spawns local-inference/.venv/bin/python infer.py with JSON stdin.
    Reads stdout/stderr concurrently to prevent pipe deadlock.
    """
    if not _is_available():
        return {"success": False, "error": "Local inference not set up. Run setup.sh in local-inference/"}

    payload = json.dumps({"action": action, **params})

    try:
        proc = await asyncio.create_subprocess_exec(
            str(_VENV_PYTHON), str(_INFER_SCRIPT),
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(_INFERENCE_DIR),
        )

        stdout_data, stderr_data = await proc.communicate(input=payload.encode())

        if stderr_data:
            logger.debug("infer.py stderr: %s", stderr_data.decode(errors="replace")[-500:])

        if proc.returncode != 0:
            err_msg = stderr_data.decode(errors="replace")[-300:] if stderr_data else "unknown error"
            return {"success": False, "error": f"Inference process failed (rc={proc.returncode}): {err_msg}"}

        stdout_text = stdout_data.decode().strip()
        if not stdout_text:
            return {"success": False, "error": "Inference returned empty output"}

        # infer.py may emit progress JSON lines before the final result
        # Take the last valid JSON line as the result
        lines = stdout_text.split("\n")
        result_line = lines[-1]
        try:
            result = json.loads(result_line)
        except json.JSONDecodeError:
            return {"success": False, "error": f"Invalid JSON from inference: {result_line[:200]}"}

        # Normalize: if result has no 'success' key, infer from 'error'
        if "success" not in result:
            result["success"] = "error" not in result

        return result

    except asyncio.TimeoutError:
        return {"success": False, "error": "Inference timed out"}
    except Exception as e:
        return {"success": False, "error": f"Inference error: {e}"}


async def generate_image(
    prompt: str,
    model: str = "animagine_xl",
    width: int = 1024,
    height: int = 1024,
    steps: int = 25,
    **kwargs: Any,
) -> dict[str, Any]:
    """Generate an image using a local model."""
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
    """Generate a video using AnimateDiff or SVD."""
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
    """Apply anime style transfer."""
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
    """Generate video using ControlNet hybrid pipeline."""
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
    """Extract control map from image."""
    return await run_inference("extract_control", {
        "image_base64": image_base64,
        "control_type": control_type,
        **kwargs,
    })
