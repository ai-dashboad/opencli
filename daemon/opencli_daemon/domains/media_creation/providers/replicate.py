"""Replicate cloud video provider (minimax/video-01 Hailuo).

Ported from daemon/lib/domains/media_creation/ai_video/replicate_provider.dart.
"""

import asyncio
import time
from typing import Any

import httpx

from .base import AIVideoProvider


class ReplicateProvider(AIVideoProvider):
    name = "Replicate"
    id = "replicate"

    def __init__(self, api_key: str) -> None:
        self.api_key = api_key
        self._base_url = "https://api.replicate.com/v1"

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"}

    async def submit(self, prompt: str, *, image_url: str = "", style: str = "", **kwargs: Any) -> str:
        async with httpx.AsyncClient(timeout=30.0) as client:
            body: dict[str, Any] = {"input": {"prompt": prompt}}
            if image_url:
                body["input"]["first_frame_image"] = image_url

            resp = await client.post(
                f"{self._base_url}/models/minimax/video-01/predictions",
                headers=self._headers(),
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()
            return data["id"]

    async def poll(self, job_id: str) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{self._base_url}/predictions/{job_id}",
                headers=self._headers(),
            )
            resp.raise_for_status()
            data = resp.json()

            status = data.get("status", "")
            if status == "succeeded":
                output = data.get("output")
                output_url = output if isinstance(output, str) else (output[0] if isinstance(output, list) and output else "")
                return {"status": "completed", "progress": 100, "output_url": output_url}
            elif status == "failed":
                return {"status": "failed", "error": data.get("error", "Unknown error")}
            else:
                return {"status": "running", "progress": 50}

    async def download(self, url: str, dest_path: str) -> str:
        async with httpx.AsyncClient(timeout=120.0, follow_redirects=True) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            with open(dest_path, "wb") as f:
                f.write(resp.content)
        return dest_path
