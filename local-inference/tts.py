#!/usr/bin/env python3
"""
OpenCLI TTS Engine — Edge TTS wrapper.

Reads JSON from stdin, generates speech audio, writes JSON to stdout.

Input:  {"text": "...", "voice": "zh-CN-XiaoxiaoNeural", "rate": "+0%", "pitch": "+0Hz", "output_path": "/path/to/output.mp3"}
Output: {"success": true, "output_path": "...", "duration_ms": 1234}

Requires: pip install edge-tts
"""

import asyncio
import json
import sys
import os


async def synthesize(params: dict) -> dict:
    """Generate speech audio using edge-tts."""
    try:
        import edge_tts
    except ImportError:
        return {"success": False, "error": "edge-tts not installed. Run: pip install edge-tts"}

    text = params.get("text", "")
    voice = params.get("voice", "zh-CN-XiaoxiaoNeural")
    rate = params.get("rate", "+0%")
    pitch = params.get("pitch", "+0Hz")
    output_path = params.get("output_path", "/tmp/tts_output.mp3")

    if not text.strip():
        return {"success": False, "error": "Empty text"}

    try:
        communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
        await communicate.save(output_path)

        # Get file size as rough duration estimate (mp3 ~16kBps for speech)
        file_size = os.path.getsize(output_path)
        duration_ms = int(file_size / 16 * 1000 / 1024)  # rough estimate

        return {
            "success": True,
            "output_path": output_path,
            "duration_ms": duration_ms,
            "file_size": file_size,
            "voice": voice,
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


async def list_voices(language: str = None) -> dict:
    """List available Edge TTS voices."""
    try:
        import edge_tts
        voices = await edge_tts.list_voices()
        if language:
            voices = [v for v in voices if v["Locale"].startswith(language)]
        return {
            "success": True,
            "voices": [
                {
                    "id": v["ShortName"],
                    "name": v["FriendlyName"],
                    "language": v["Locale"],
                    "gender": v["Gender"],
                }
                for v in voices
            ],
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def main():
    """Read JSON from stdin and dispatch."""
    try:
        data = json.loads(sys.stdin.read())
    except json.JSONDecodeError as e:
        print(json.dumps({"success": False, "error": f"Invalid JSON: {e}"}))
        return

    action = data.get("action", "synthesize")

    if action == "list_voices":
        result = asyncio.run(list_voices(data.get("language")))
    else:
        result = asyncio.run(synthesize(data))

    print(json.dumps(result))


if __name__ == "__main__":
    main()
