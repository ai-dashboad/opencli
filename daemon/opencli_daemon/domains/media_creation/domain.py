"""Media Creation domain — 19 task types spanning local AI, cloud APIs, FFmpeg, TTS.

Ported from daemon/lib/domains/media_creation/media_creation_domain.dart.
Key win: local inference is now a direct Python import (no subprocess).
"""

import asyncio
import base64
import os
import tempfile
import time
from pathlib import Path
from typing import Any

from ..base import TaskDomain, DomainDisplayConfig, ProgressCallback
from . import local_inference
from . import tts_registry
from .ffmpeg_runner import run_ffmpeg

_HOME = os.environ.get("HOME", ".")
_OUTPUT_DIR = Path(_HOME) / ".opencli" / "output"


class MediaCreationDomain(TaskDomain):
    id = "media_creation"
    name = "Media Creation"
    description = "AI image/video generation, TTS, FFmpeg effects, subtitles, assembly"
    icon = "movie_creation"
    color_hex = 0xFF7C4DFF

    task_types = [
        # FFmpeg effects
        "media_animate_photo",
        "media_create_slideshow",
        # Cloud AI
        "media_ai_generate_video",
        "media_ai_generate_image",
        # Local AI (direct Python — no subprocess!)
        "media_local_generate_image",
        "media_local_generate_video",
        "media_local_style_transfer",
        "media_local_generate_video_v3",
        "media_local_controlnet_video",
        "media_local_extract_control",
        # Upscale / interpolation
        "media_upscale_video",
        "media_interpolate_video",
        "media_local_upscale_video_path",
        # TTS
        "media_tts_synthesize",
        "media_tts_list_voices",
        # FFmpeg post-production
        "media_audio_mix",
        "media_subtitle_overlay",
        "media_scene_transition",
        "media_video_assembly",
    ]

    display_configs = {
        "media_animate_photo": DomainDisplayConfig(
            card_type="media", title_template="Photo Animation",
            icon="animation", color_hex=0xFF7C4DFF),
        "media_ai_generate_video": DomainDisplayConfig(
            card_type="media", title_template="AI Video",
            icon="movie_creation", color_hex=0xFF7C4DFF),
        "media_local_generate_image": DomainDisplayConfig(
            card_type="media", title_template="Local AI Image",
            icon="brush", color_hex=0xFF7C4DFF),
        "media_tts_synthesize": DomainDisplayConfig(
            card_type="media", title_template="TTS",
            icon="record_voice_over", color_hex=0xFF7C4DFF),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        return await self.execute_task_with_progress(task_type, task_data)

    async def execute_task_with_progress(
        self,
        task_type: str,
        task_data: dict[str, Any],
        *,
        on_progress: ProgressCallback | None = None,
    ) -> dict[str, Any]:
        _OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

        try:
            # ── FFmpeg effects ────────────────────────────────────
            if task_type == "media_animate_photo":
                return await self._animate_photo(task_data, on_progress)
            elif task_type == "media_create_slideshow":
                return await self._create_slideshow(task_data, on_progress)

            # ── Cloud AI ──────────────────────────────────────────
            elif task_type == "media_ai_generate_video":
                return await self._ai_generate_video(task_data, on_progress)
            elif task_type == "media_ai_generate_image":
                return await self._ai_generate_image(task_data, on_progress)

            # ── Local AI (DIRECT PYTHON — no subprocess!) ─────────
            elif task_type == "media_local_generate_image":
                if on_progress:
                    on_progress({"progress": 10, "status_message": "Starting local image generation..."})
                result = await local_inference.generate_image(
                    prompt=task_data.get("prompt", ""),
                    model=task_data.get("model", "animagine_xl"),
                    width=task_data.get("width", 1024),
                    height=task_data.get("height", 1024),
                    steps=task_data.get("steps", 25),
                )
                result["domain"] = "media_creation"
                result["card_type"] = "media"
                return result

            elif task_type == "media_local_generate_video":
                return await self._local_generate_video(task_data, on_progress)
            elif task_type == "media_local_generate_video_v3":
                return await self._local_generate_video(task_data, on_progress)
            elif task_type == "media_local_style_transfer":
                result = await local_inference.style_transfer(
                    image_path=task_data.get("image_path", ""),
                    model=task_data.get("model", "animegan_v3"),
                )
                result["domain"] = "media_creation"
                return result
            elif task_type == "media_local_controlnet_video":
                result = await local_inference.controlnet_video(
                    image_path=task_data.get("image_path", ""),
                    prompt=task_data.get("prompt", ""),
                    control_type=task_data.get("control_type", "lineart_anime"),
                )
                result["domain"] = "media_creation"
                return result
            elif task_type == "media_local_extract_control":
                result = await local_inference.extract_control(
                    image_path=task_data.get("image_path", ""),
                    control_type=task_data.get("control_type", "lineart_anime"),
                )
                result["domain"] = "media_creation"
                return result

            # ── Upscale / interpolation ───────────────────────────
            elif task_type in ("media_upscale_video", "media_local_upscale_video_path"):
                result = await local_inference.run_inference("upscale_video", task_data)
                result["domain"] = "media_creation"
                return result
            elif task_type == "media_interpolate_video":
                result = await local_inference.run_inference("interpolate_video", task_data)
                result["domain"] = "media_creation"
                return result

            # ── TTS ───────────────────────────────────────────────
            elif task_type == "media_tts_synthesize":
                return await self._tts_synthesize(task_data)
            elif task_type == "media_tts_list_voices":
                voices = await tts_registry.list_edge_tts_voices()
                return {"success": True, "voices": voices, "domain": "media_creation"}

            # ── FFmpeg post-production ────────────────────────────
            elif task_type == "media_audio_mix":
                return await self._audio_mix(task_data)
            elif task_type == "media_subtitle_overlay":
                return await self._subtitle_overlay(task_data)
            elif task_type == "media_scene_transition":
                return await self._scene_transition(task_data)
            elif task_type == "media_video_assembly":
                return await self._video_assembly(task_data)

            return {"success": False, "error": f"Unknown task: {task_type}", "domain": "media_creation"}

        except Exception as e:
            return {"success": False, "error": str(e), "domain": "media_creation"}

    # ── FFmpeg Effects ────────────────────────────────────────────────────

    async def _animate_photo(self, data: dict, on_progress: ProgressCallback | None) -> dict:
        image_path = data.get("image_path", "")
        effect = data.get("effect", "ken_burns")
        duration = data.get("duration", 5)

        if not image_path or not Path(image_path).exists():
            return {"success": False, "error": "Image not found", "domain": "media_creation"}

        output = str(_OUTPUT_DIR / f"animated_{int(time.time() * 1000)}.mp4")

        # Ken Burns with pre-scale to avoid zoompan slowness on small images
        zoom_filters = {
            "ken_burns": "zoompan=z='min(zoom+0.0015,1.5)':d=125:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=25",
            "zoom_in": "zoompan=z='min(zoom+0.002,2.0)':d=125:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=25",
            "zoom_out": "zoompan=z='if(lte(zoom,1.0),1.5,max(1.001,zoom-0.002))':d=125:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=25",
            "pan_left": "zoompan=z='1.2':d=125:x='iw*0.2*on/125':y='ih/2-(ih/zoom/2)':s=1280x720:fps=25",
            "pan_right": "zoompan=z='1.2':d=125:x='iw*0.8-iw*0.6*on/125':y='ih/2-(ih/zoom/2)':s=1280x720:fps=25",
            "pulse": "zoompan=z='1.1+0.1*sin(2*PI*on/25)':d=125:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=25",
        }
        zoom = zoom_filters.get(effect, zoom_filters["ken_burns"])
        vf = f"scale=1280:720:force_original_aspect_ratio=increase:flags=lanczos,crop=1280:720,{zoom}"

        if on_progress:
            on_progress({"progress": 20, "status_message": f"Applying {effect} effect..."})

        _, stderr, rc = await run_ffmpeg([
            "-y", "-loop", "1", "-i", image_path,
            "-vf", vf,
            "-t", str(duration), "-c:v", "libx264", "-pix_fmt", "yuv420p",
            output,
        ], timeout=120.0)

        if rc != 0:
            return {"success": False, "error": f"FFmpeg error: {stderr[:500]}", "domain": "media_creation"}

        return {
            "success": True, "path": output, "effect": effect,
            "duration": duration, "domain": "media_creation", "card_type": "media",
        }

    async def _create_slideshow(self, data: dict, on_progress: ProgressCallback | None) -> dict:
        images = data.get("images", [])
        duration_per = data.get("duration", 3)
        transition = data.get("transition", "fade")

        if len(images) < 2:
            return {"success": False, "error": "Need at least 2 images", "domain": "media_creation"}

        output = str(_OUTPUT_DIR / f"slideshow_{int(time.time() * 1000)}.mp4")

        # Build xfade filter chain
        inputs = []
        for img in images:
            inputs.extend(["-loop", "1", "-t", str(duration_per), "-i", img])

        filter_parts = []
        for i in range(len(images) - 1):
            src = f"[{i}]" if i == 0 else f"[v{i}]"
            offset = duration_per * (i + 1) - 1
            filter_parts.append(f"{src}[{i+1}]xfade=transition={transition}:duration=1:offset={offset}[v{i+1}]")

        last = f"[v{len(images)-1}]"
        filter_complex = ";".join(filter_parts)

        _, stderr, rc = await run_ffmpeg([
            "-y", *inputs,
            "-filter_complex", f"{filter_complex}{last}format=yuv420p[out]",
            "-map", "[out]", "-c:v", "libx264", output,
        ], timeout=120.0)

        if rc != 0:
            return {"success": False, "error": f"FFmpeg error: {stderr[:500]}", "domain": "media_creation"}

        return {"success": True, "path": output, "count": len(images),
                "domain": "media_creation", "card_type": "media"}

    # ── Cloud AI ──────────────────────────────────────────────────────────

    async def _ai_generate_video(self, data: dict, on_progress: ProgressCallback | None) -> dict:
        from opencli_daemon.config import load_config, get_nested
        config = load_config()
        api_key = get_nested(config, "ai_video.api_keys.replicate", "")
        if not api_key:
            return {"success": False, "error": "Replicate API key not configured", "domain": "media_creation"}

        from .providers.replicate import ReplicateProvider
        provider = ReplicateProvider(api_key)

        prompt = data.get("prompt", "")
        image_url = data.get("image_url", data.get("image", ""))

        if on_progress:
            on_progress({"progress": 5, "status_message": "Submitting to Replicate..."})

        job_id = await provider.submit(prompt, image_url=image_url)

        # Poll loop
        for i in range(72):  # 72 * 5s = 6 min timeout
            await asyncio.sleep(5)
            status = await provider.poll(job_id)

            if on_progress:
                on_progress({"progress": min(90, 10 + i * 2), "status_message": f"Generating... ({status['status']})"})

            if status["status"] == "completed":
                output_url = status.get("output_url", "")
                if output_url:
                    dest = str(_OUTPUT_DIR / f"ai_video_{int(time.time() * 1000)}.mp4")
                    await provider.download(output_url, dest)
                    return {"success": True, "path": dest, "provider": "replicate",
                            "domain": "media_creation", "card_type": "media"}
                return {"success": False, "error": "No output URL", "domain": "media_creation"}
            elif status["status"] == "failed":
                return {"success": False, "error": status.get("error", "Generation failed"),
                        "domain": "media_creation"}

        return {"success": False, "error": "Generation timed out", "domain": "media_creation"}

    async def _ai_generate_image(self, data: dict, on_progress: ProgressCallback | None) -> dict:
        prompt = data.get("prompt", "")
        provider_name = data.get("provider", "pollinations")

        if provider_name == "pollinations":
            from .providers.pollinations import generate_image
            result = await generate_image(
                prompt,
                width=data.get("width", 1024),
                height=data.get("height", 1024),
                output_dir=str(_OUTPUT_DIR),
            )
            result["domain"] = "media_creation"
            result["card_type"] = "media"
            return result

        # Replicate fallback
        from opencli_daemon.config import load_config, get_nested
        config = load_config()
        api_key = get_nested(config, "ai_video.api_keys.replicate", "")
        if not api_key:
            return {"success": False, "error": "API key not configured", "domain": "media_creation"}

        import httpx
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions",
                headers={"Authorization": f"Bearer {api_key}"},
                json={"input": {"prompt": prompt, "num_outputs": 1}},
            )
            resp.raise_for_status()
            job = resp.json()
            job_id = job["id"]

            for _ in range(90):
                await asyncio.sleep(2)
                poll_resp = await client.get(
                    f"https://api.replicate.com/v1/predictions/{job_id}",
                    headers={"Authorization": f"Bearer {api_key}"},
                )
                poll_data = poll_resp.json()
                if poll_data["status"] == "succeeded":
                    output = poll_data.get("output", [])
                    url = output[0] if output else ""
                    if url:
                        dest = str(_OUTPUT_DIR / f"ai_img_{int(time.time() * 1000)}.png")
                        dl = await client.get(url, follow_redirects=True)
                        with open(dest, "wb") as f:
                            f.write(dl.content)
                        return {"success": True, "path": dest, "domain": "media_creation", "card_type": "media"}
                elif poll_data["status"] == "failed":
                    return {"success": False, "error": poll_data.get("error", "Failed"), "domain": "media_creation"}

        return {"success": False, "error": "Timed out", "domain": "media_creation"}

    # ── Local AI video ────────────────────────────────────────────────────

    async def _local_generate_video(self, data: dict, on_progress: ProgressCallback | None) -> dict:
        if on_progress:
            on_progress({"progress": 10, "status_message": "Starting local video generation..."})
        result = await local_inference.generate_video(
            prompt=data.get("prompt", ""),
            image_path=data.get("image_path", ""),
            model=data.get("model", "animatediff_v3"),
            frames=data.get("frames", 16),
        )
        result["domain"] = "media_creation"
        result["card_type"] = "media"
        return result

    # ── TTS ───────────────────────────────────────────────────────────────

    async def _tts_synthesize(self, data: dict) -> dict:
        text = data.get("text", "")
        voice = data.get("voice", "zh-CN-XiaoxiaoNeural")
        provider = data.get("provider", "edge_tts")

        if provider == "elevenlabs":
            from opencli_daemon.config import load_config, get_nested
            config = load_config()
            api_key = get_nested(config, "ai_video.api_keys.elevenlabs", "")
            result = await tts_registry.synthesize_elevenlabs(
                text, voice_id=data.get("voice_id", voice), api_key=api_key,
            )
        else:
            result = await tts_registry.synthesize_edge_tts(text, voice=voice)

        result["domain"] = "media_creation"
        return result

    # ── FFmpeg post-production ────────────────────────────────────────────

    async def _audio_mix(self, data: dict) -> dict:
        voice_path = data.get("voice_path", "")
        music_path = data.get("music_path", "")
        music_volume = data.get("music_volume", 0.3)
        output = str(_OUTPUT_DIR / f"mix_{int(time.time() * 1000)}.mp3")

        _, stderr, rc = await run_ffmpeg([
            "-y", "-i", voice_path, "-i", music_path,
            "-filter_complex",
            f"[1]volume={music_volume}[bg];[0][bg]amix=inputs=2:duration=first:dropout_transition=2",
            "-c:a", "libmp3lame", output,
        ])
        if rc != 0:
            return {"success": False, "error": stderr[:500], "domain": "media_creation"}
        return {"success": True, "path": output, "domain": "media_creation"}

    async def _subtitle_overlay(self, data: dict) -> dict:
        video_path = data.get("video_path", "")
        subtitle_path = data.get("subtitle_path", "")
        output = str(_OUTPUT_DIR / f"subbed_{int(time.time() * 1000)}.mp4")

        # Use soft subtitles (Homebrew FFmpeg may lack libass)
        _, stderr, rc = await run_ffmpeg([
            "-y", "-i", video_path, "-i", subtitle_path,
            "-c:v", "copy", "-c:a", "copy", "-c:s", "mov_text",
            output,
        ])
        if rc != 0:
            return {"success": False, "error": stderr[:500], "domain": "media_creation"}
        return {"success": True, "path": output, "domain": "media_creation"}

    async def _scene_transition(self, data: dict) -> dict:
        video1 = data.get("video1", "")
        video2 = data.get("video2", "")
        transition = data.get("transition", "fade")
        duration = data.get("duration", 1)
        output = str(_OUTPUT_DIR / f"transition_{int(time.time() * 1000)}.mp4")

        _, stderr, rc = await run_ffmpeg([
            "-y", "-i", video1, "-i", video2,
            "-filter_complex",
            f"[0][1]xfade=transition={transition}:duration={duration}:offset=0[v];"
            f"[0:a][1:a]acrossfade=d={duration}[a]",
            "-map", "[v]", "-map", "[a]",
            "-c:v", "libx264", "-c:a", "aac", output,
        ])
        if rc != 0:
            return {"success": False, "error": stderr[:500], "domain": "media_creation"}
        return {"success": True, "path": output, "domain": "media_creation"}

    async def _video_assembly(self, data: dict) -> dict:
        clips = data.get("clips", [])
        if not clips:
            return {"success": False, "error": "No clips to assemble", "domain": "media_creation"}

        output = str(_OUTPUT_DIR / f"assembled_{int(time.time() * 1000)}.mp4")

        # Write concat file
        concat_file = str(_OUTPUT_DIR / f"concat_{int(time.time() * 1000)}.txt")
        with open(concat_file, "w") as f:
            for clip in clips:
                f.write(f"file '{clip}'\n")

        _, stderr, rc = await run_ffmpeg([
            "-y", "-f", "concat", "-safe", "0", "-i", concat_file,
            "-c:v", "libx264", "-c:a", "aac", output,
        ])
        if rc != 0:
            return {"success": False, "error": stderr[:500], "domain": "media_creation"}
        return {"success": True, "path": output, "count": len(clips), "domain": "media_creation"}
