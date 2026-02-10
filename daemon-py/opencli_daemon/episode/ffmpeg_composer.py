"""FFmpeg composer for episode video assembly.

Ported from daemon/lib/episode/ffmpeg_composer.dart (752 lines).
Handles: audio mixing, subtitle overlay, transitions, video concat, LUT grading.
"""

import os
import time
from pathlib import Path
from typing import Any

from opencli_daemon.domains.media_creation.ffmpeg_runner import run_ffmpeg

_OUTPUT_DIR = Path(os.environ.get("HOME", ".")) / ".opencli" / "output"


async def mix_audio(
    voice_path: str,
    music_path: str | None = None,
    music_volume: float = 0.3,
    output_path: str = "",
) -> dict[str, Any]:
    """Mix voice + background music."""
    if not output_path:
        output_path = str(_OUTPUT_DIR / f"mix_{int(time.time() * 1000)}.mp3")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    if not music_path:
        # Just copy voice
        import shutil
        shutil.copy2(voice_path, output_path)
        return {"success": True, "path": output_path}

    _, stderr, rc = await run_ffmpeg([
        "-y", "-i", voice_path, "-i", music_path,
        "-filter_complex",
        f"[1]volume={music_volume}[bg];[0][bg]amix=inputs=2:duration=first:dropout_transition=2",
        "-c:a", "libmp3lame", output_path,
    ])
    if rc != 0:
        return {"success": False, "error": stderr[:500]}
    return {"success": True, "path": output_path}


async def concat_videos(
    clip_paths: list[str],
    output_path: str = "",
    transition: str = "",
    transition_duration: float = 0.5,
) -> dict[str, Any]:
    """Concatenate video clips, optionally with transitions."""
    if not clip_paths:
        return {"success": False, "error": "No clips to concatenate"}

    if not output_path:
        output_path = str(_OUTPUT_DIR / f"concat_{int(time.time() * 1000)}.mp4")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    if len(clip_paths) == 1:
        import shutil
        shutil.copy2(clip_paths[0], output_path)
        return {"success": True, "path": output_path}

    if not transition:
        # Simple concat via concat demuxer
        concat_file = str(_OUTPUT_DIR / f"clist_{int(time.time() * 1000)}.txt")
        with open(concat_file, "w") as f:
            for p in clip_paths:
                f.write(f"file '{p}'\n")

        _, stderr, rc = await run_ffmpeg([
            "-y", "-f", "concat", "-safe", "0", "-i", concat_file,
            "-c:v", "libx264", "-c:a", "aac", output_path,
        ])
    else:
        # xfade transitions
        inputs = []
        for p in clip_paths:
            inputs.extend(["-i", p])

        # Build xfade chain
        fc_parts = []
        for i in range(len(clip_paths) - 1):
            src = f"[{i}]" if i == 0 else f"[v{i}]"
            offset = max(0, (i + 1) * 3 - transition_duration)  # rough estimate
            fc_parts.append(
                f"{src}[{i+1}]xfade=transition={transition}:"
                f"duration={transition_duration}:offset={offset}[v{i+1}]"
            )

        last = f"[v{len(clip_paths) - 1}]"
        fc = ";".join(fc_parts) + f";{last}format=yuv420p[out]"

        _, stderr, rc = await run_ffmpeg([
            "-y", *inputs,
            "-filter_complex", fc,
            "-map", "[out]", "-c:v", "libx264", output_path,
        ])

    if rc != 0:
        return {"success": False, "error": stderr[:500]}
    return {"success": True, "path": output_path}


async def mux_video_audio(
    video_path: str,
    audio_path: str,
    output_path: str = "",
) -> dict[str, Any]:
    """Mux video + audio into final output."""
    if not output_path:
        output_path = str(_OUTPUT_DIR / f"muxed_{int(time.time() * 1000)}.mp4")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    _, stderr, rc = await run_ffmpeg([
        "-y", "-i", video_path, "-i", audio_path,
        "-c:v", "copy", "-c:a", "aac", "-shortest",
        output_path,
    ])
    if rc != 0:
        return {"success": False, "error": stderr[:500]}
    return {"success": True, "path": output_path}


async def apply_lut(
    video_path: str,
    lut_path: str,
    output_path: str = "",
) -> dict[str, Any]:
    """Apply a LUT color grade to video."""
    if not output_path:
        output_path = str(_OUTPUT_DIR / f"graded_{int(time.time() * 1000)}.mp4")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    _, stderr, rc = await run_ffmpeg([
        "-y", "-i", video_path,
        "-vf", f"lut3d='{lut_path}'",
        "-c:v", "libx264", "-c:a", "copy", output_path,
    ])
    if rc != 0:
        return {"success": False, "error": stderr[:500]}
    return {"success": True, "path": output_path}


async def encode_for_platform(
    video_path: str,
    platform: str = "youtube",
    output_path: str = "",
) -> dict[str, Any]:
    """Re-encode video for a specific platform."""
    presets = {
        "youtube": {"w": 1920, "h": 1080, "fps": 24, "bitrate": "12M"},
        "tiktok": {"w": 1080, "h": 1920, "fps": 30, "bitrate": "8M"},
        "ecommerce": {"w": 720, "h": 1280, "fps": 30, "bitrate": "6M"},
    }
    preset = presets.get(platform, presets["youtube"])

    if not output_path:
        output_path = str(_OUTPUT_DIR / f"{platform}_{int(time.time() * 1000)}.mp4")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    _, stderr, rc = await run_ffmpeg([
        "-y", "-i", video_path,
        "-vf", f"scale={preset['w']}:{preset['h']}:force_original_aspect_ratio=decrease,"
               f"pad={preset['w']}:{preset['h']}:-1:-1:color=black",
        "-r", str(preset["fps"]),
        "-b:v", preset["bitrate"],
        "-c:v", "libx264", "-c:a", "aac", output_path,
    ])
    if rc != 0:
        return {"success": False, "error": stderr[:500]}
    return {"success": True, "path": output_path, "platform": platform}
