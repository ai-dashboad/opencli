"""Pollinations.ai free image generation provider.

No API key needed. GET request returns raw JPEG bytes.
"""

import time
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx


async def generate_image(
    prompt: str,
    width: int = 1024,
    height: int = 1024,
    output_dir: str = "/tmp",
) -> dict[str, Any]:
    """Generate image via Pollinations.ai (free, no API key)."""
    encoded = quote(prompt)
    url = f"https://image.pollinations.ai/prompt/{encoded}?width={width}&height={height}&model=flux&nologo=true"

    output_path = Path(output_dir) / f"pollinations_{int(time.time() * 1000)}.jpg"
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        async with httpx.AsyncClient(timeout=120.0, follow_redirects=True) as client:
            resp = await client.get(url)
            if resp.status_code != 200:
                return {"success": False, "error": f"Pollinations error: {resp.status_code}"}

            with open(output_path, "wb") as f:
                f.write(resp.content)

            return {
                "success": True,
                "path": str(output_path),
                "size_bytes": len(resp.content),
                "provider": "pollinations",
            }
    except Exception as e:
        return {"success": False, "error": f"Pollinations error: {e}"}
