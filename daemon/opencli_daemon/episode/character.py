"""Character consistency via IP-Adapter.

Ported from daemon/lib/episode/character_manager.dart.
Uses direct Python import for IP-Adapter (no subprocess).
"""

import asyncio
import os
import sys
from pathlib import Path
from typing import Any

from . import store

_INFERENCE_DIR = Path(__file__).resolve().parents[2] / "local-inference"


async def extract_embedding(image_path: str) -> bytes | None:
    """Extract face embedding from reference image using IP-Adapter."""
    if not Path(image_path).exists():
        return None

    try:
        if str(_INFERENCE_DIR) not in sys.path:
            sys.path.insert(0, str(_INFERENCE_DIR))

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, _extract_sync, image_path)
        return result
    except Exception as e:
        print(f"[Character] Embedding extraction failed: {e}")
        return None


def _extract_sync(image_path: str) -> bytes | None:
    try:
        from ip_adapter import extract_embedding as _extract
        return _extract(image_path)
    except ImportError:
        return None
    except Exception:
        return None


async def apply_consistency(
    prompt: str,
    character_id: str,
    episode_id: str | None = None,
) -> dict[str, Any]:
    """Apply character consistency to a generation prompt."""
    chars = await store.list_characters(episode_id)
    char = next((c for c in chars if c.get("character_id") == character_id), None)

    if char is None:
        return {"prompt": prompt, "applied": False}

    # Append visual description to prompt
    visual_desc = char.get("visual_description", "")
    if visual_desc:
        enhanced_prompt = f"{prompt}, {visual_desc}"
    else:
        enhanced_prompt = prompt

    return {
        "prompt": enhanced_prompt,
        "applied": True,
        "character_name": char.get("name", ""),
        "embedding_available": char.get("embedding") is not None,
    }
