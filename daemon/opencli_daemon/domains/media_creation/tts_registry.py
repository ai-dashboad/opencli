"""TTS provider registry — Edge TTS (free) + ElevenLabs (paid).

Ported from daemon/lib/domains/media_creation/tts/.
Direct Python import for Edge TTS (no subprocess needed).
"""

import asyncio
import base64
import os
import tempfile
import time
from pathlib import Path
from typing import Any

import httpx


async def synthesize_edge_tts(text: str, voice: str = "zh-CN-XiaoxiaoNeural", **kwargs: Any) -> dict:
    """Synthesize speech using edge-tts (free, no API key)."""
    try:
        import edge_tts
    except ImportError:
        return {"success": False, "error": "edge-tts not installed (pip install edge-tts)"}

    output_path = Path(tempfile.mkdtemp()) / f"tts_{int(time.time() * 1000)}.mp3"

    try:
        communicate = edge_tts.Communicate(text, voice)
        await communicate.save(str(output_path))

        with open(output_path, "rb") as f:
            audio_bytes = f.read()

        audio_b64 = base64.b64encode(audio_bytes).decode()
        return {
            "success": True,
            "audio_base64": audio_b64,
            "path": str(output_path),
            "voice": voice,
            "format": "mp3",
        }
    except Exception as e:
        return {"success": False, "error": f"Edge TTS error: {e}"}


async def synthesize_elevenlabs(
    text: str,
    voice_id: str = "21m00Tcm4TlvDq8ikWAM",
    api_key: str = "",
    **kwargs: Any,
) -> dict:
    """Synthesize speech using ElevenLabs API (paid)."""
    if not api_key:
        return {"success": False, "error": "ElevenLabs API key not configured"}

    output_path = Path(tempfile.mkdtemp()) / f"tts_{int(time.time() * 1000)}.mp3"

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}",
                headers={"xi-api-key": api_key},
                json={
                    "text": text,
                    "model_id": "eleven_multilingual_v2",
                    "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
                },
            )
            if resp.status_code != 200:
                return {"success": False, "error": f"ElevenLabs error: {resp.status_code}"}

            with open(output_path, "wb") as f:
                f.write(resp.content)

            audio_b64 = base64.b64encode(resp.content).decode()
            return {
                "success": True,
                "audio_base64": audio_b64,
                "path": str(output_path),
                "voice_id": voice_id,
                "format": "mp3",
            }
    except Exception as e:
        return {"success": False, "error": f"ElevenLabs error: {e}"}


async def list_edge_tts_voices() -> list[dict]:
    """List available Edge TTS voices."""
    try:
        import edge_tts
        voices = await edge_tts.list_voices()
        return [
            {"id": v["ShortName"], "name": v["FriendlyName"],
             "locale": v["Locale"], "gender": v["Gender"]}
            for v in voices
        ]
    except Exception:
        return []
