"""Direct Python integration with local-inference/ modules.

This is THE KEY WIN of the FastAPI migration: instead of spawning a
subprocess and communicating via JSON pipes, we import the inference
functions directly and call them in a thread executor.

No subprocess overhead, no pipe deadlock risk, no JSON serialization.
"""

import asyncio
import os
import sys
from pathlib import Path
from typing import Any

# Add local-inference to Python path for direct imports
_INFERENCE_DIR = Path(__file__).resolve().parents[3] / "local-inference"
if str(_INFERENCE_DIR) not in sys.path:
    sys.path.insert(0, str(_INFERENCE_DIR))

_MODELS_DIR = Path(os.environ.get("HOME", ".")) / ".opencli" / "models"
_VENV_DIR = _INFERENCE_DIR / ".venv"


def _is_available() -> bool:
    """Check if local inference environment is set up."""
    return _VENV_DIR.exists()


async def run_inference(action: str, params: dict[str, Any]) -> dict[str, Any]:
    """Run an inference action in a thread executor (non-blocking).

    This replaces the Dart subprocess approach entirely.
    CPU-bound inference runs in a thread pool so it won't block the event loop.
    """
    if not _is_available():
        return {"success": False, "error": "Local inference not set up. Run /api/v1/local-models/setup"}

    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _run_sync, action, params)


def _run_sync(action: str, params: dict[str, Any]) -> dict[str, Any]:
    """Synchronous inference wrapper — runs in thread pool."""
    try:
        # Import infer.py's handle_action directly
        from infer import handle_action
        return handle_action(action, params)
    except ImportError as e:
        return {"success": False, "error": f"Cannot import infer module: {e}. "
                f"Ensure local-inference/infer.py exists and venv is set up."}
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
        "output_dir": str(_MODELS_DIR.parent / "output"),
        **kwargs,
    })


async def generate_video(
    prompt: str = "",
    image_path: str = "",
    model: str = "animatediff_v3",
    frames: int = 16,
    **kwargs: Any,
) -> dict[str, Any]:
    """Generate a video using AnimateDiff or SVD."""
    return await run_inference("generate_video", {
        "prompt": prompt,
        "image_path": image_path,
        "model": model,
        "frames": frames,
        "output_dir": str(_MODELS_DIR.parent / "output"),
        **kwargs,
    })


async def style_transfer(
    image_path: str,
    model: str = "animegan_v3",
    **kwargs: Any,
) -> dict[str, Any]:
    """Apply anime style transfer."""
    return await run_inference("style_transfer", {
        "image_path": image_path,
        "model": model,
        "output_dir": str(_MODELS_DIR.parent / "output"),
        **kwargs,
    })


async def controlnet_video(
    image_path: str,
    prompt: str,
    control_type: str = "lineart_anime",
    **kwargs: Any,
) -> dict[str, Any]:
    """Generate video using ControlNet hybrid pipeline."""
    return await run_inference("controlnet_video", {
        "image_path": image_path,
        "prompt": prompt,
        "control_type": control_type,
        "output_dir": str(_MODELS_DIR.parent / "output"),
        **kwargs,
    })


async def extract_control(
    image_path: str,
    control_type: str = "lineart_anime",
    **kwargs: Any,
) -> dict[str, Any]:
    """Extract control map from image."""
    return await run_inference("extract_control", {
        "image_path": image_path,
        "control_type": control_type,
        "output_dir": str(_MODELS_DIR.parent / "output"),
        **kwargs,
    })
