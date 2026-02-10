"""Episode generator — 10-phase orchestrator.

Ported from daemon/lib/episode/episode_generator.dart (1334 lines).
Phases: images → videos (batched) → TTS → subtitles → audio mix
        → scene assembly → final concat → post-processing → LUT → encode
"""

import asyncio
import json
import os
import time
from pathlib import Path
from typing import Any, Callable

from .script import EpisodeScript, EpisodeScene
from .subtitles import generate_ass
from . import ffmpeg_composer, store, character
from opencli_daemon.domains.media_creation import local_inference, tts_registry

_HOME = os.environ.get("HOME", ".")
_OUTPUT_DIR = Path(_HOME) / ".opencli" / "output" / "episodes"

ProgressCallback = Callable[[dict[str, Any]], None]


async def generate_episode(
    episode_id: str,
    script: EpisodeScript,
    *,
    on_progress: ProgressCallback | None = None,
    image_model: str = "animagine_xl",
    video_model: str = "animatediff_v3",
    quality: str = "standard",
    color_grade: str = "",
    export_platform: str = "",
    cancelled: Callable[[], bool] | None = None,
) -> dict[str, Any]:
    """Generate a complete episode from script."""
    episode_dir = _OUTPUT_DIR / episode_id
    episode_dir.mkdir(parents=True, exist_ok=True)

    total_phases = 10
    scenes = script.scenes
    if not scenes:
        return {"success": False, "error": "No scenes in script"}

    def _progress(phase: int, msg: str, pct: float = 0) -> None:
        if on_progress:
            overall = ((phase - 1) / total_phases + pct / total_phases / 100) * 100
            on_progress({
                "progress": min(99, overall),
                "phase": phase,
                "total_phases": total_phases,
                "status_message": msg,
            })
        # Update DB
        asyncio.ensure_future(
            store.update_episode_status(episode_id, "generating", overall / 100)
        )

    def _check_cancelled() -> bool:
        return cancelled() if cancelled else False

    try:
        # ── Phase 1: Generate keyframe images ────────────────────
        _progress(1, "Generating keyframe images...")
        keyframe_paths: list[str] = []

        for i, scene in enumerate(scenes):
            if _check_cancelled():
                return {"success": False, "error": "Cancelled"}

            prompt = scene.visual_prompt or scene.description
            # Apply character consistency
            for line in scene.dialogue:
                char_result = await character.apply_consistency(
                    prompt, line.character_id, episode_id
                )
                prompt = char_result["prompt"]

            result = await local_inference.generate_image(
                prompt=prompt,
                model=image_model,
                width=1280 if quality != "draft" else 512,
                height=720 if quality != "draft" else 288,
            )

            if result.get("success") and result.get("path"):
                keyframe_paths.append(result["path"])
            else:
                # Fallback: create a placeholder
                keyframe_paths.append("")

            _progress(1, f"Keyframe {i+1}/{len(scenes)}", (i + 1) / len(scenes) * 100)

        # ── Phase 2: Generate video clips (batched) ──────────────
        _progress(2, "Generating video clips...")
        clip_paths: list[str] = []
        batch_size = 3

        for batch_start in range(0, len(scenes), batch_size):
            if _check_cancelled():
                return {"success": False, "error": "Cancelled"}

            batch_end = min(batch_start + batch_size, len(scenes))
            tasks = []
            for i in range(batch_start, batch_end):
                kf = keyframe_paths[i] if i < len(keyframe_paths) else ""
                scene = scenes[i]
                prompt = scene.visual_prompt or scene.description

                if kf and Path(kf).exists():
                    tasks.append(local_inference.generate_video(
                        prompt=prompt, image_path=kf, model=video_model,
                        frames=max(8, int(scene.duration_seconds * 4)),
                    ))
                else:
                    # Ken Burns fallback on keyframe
                    from opencli_daemon.domains.media_creation.domain import MediaCreationDomain
                    mc = MediaCreationDomain()
                    tasks.append(mc.execute_task("media_animate_photo", {
                        "image_path": kf, "effect": "ken_burns",
                        "duration": scene.duration_seconds,
                    }))

            results = await asyncio.gather(*tasks, return_exceptions=True)
            for r in results:
                if isinstance(r, Exception):
                    clip_paths.append("")
                elif isinstance(r, dict) and r.get("path"):
                    clip_paths.append(r["path"])
                else:
                    clip_paths.append("")

            _progress(2, f"Clips {batch_end}/{len(scenes)}", batch_end / len(scenes) * 100)

        # ── Phase 3: TTS for dialogue ────────────────────────────
        _progress(3, "Synthesizing dialogue audio...")
        scene_audio_paths: list[str] = []

        for i, scene in enumerate(scenes):
            if _check_cancelled():
                return {"success": False, "error": "Cancelled"}

            if not scene.dialogue:
                scene_audio_paths.append("")
                continue

            # Concatenate all dialogue lines for the scene
            full_text = " ".join(line.text for line in scene.dialogue)
            voice = scene.dialogue[0].voice or "zh-CN-XiaoxiaoNeural"

            result = await tts_registry.synthesize_edge_tts(full_text, voice=voice)
            if result.get("success") and result.get("path"):
                scene_audio_paths.append(result["path"])
            else:
                scene_audio_paths.append("")

            _progress(3, f"TTS {i+1}/{len(scenes)}", (i + 1) / len(scenes) * 100)

        # ── Phase 4: Generate subtitles ──────────────────────────
        _progress(4, "Generating subtitles...")
        ass_path = str(episode_dir / "subtitles.ass")
        generate_ass(scenes, ass_path)

        # ── Phase 5: Audio mixing (voice + BGM) ─────────────────
        _progress(5, "Mixing audio...")
        mixed_audio_paths: list[str] = []
        for i, audio_path in enumerate(scene_audio_paths):
            if audio_path:
                mixed_audio_paths.append(audio_path)  # No BGM for now
            else:
                mixed_audio_paths.append("")

        # ── Phase 6: Scene assembly (video + audio per scene) ────
        _progress(6, "Assembling scenes...")
        assembled_scenes: list[str] = []

        for i, (clip, audio) in enumerate(zip(clip_paths, mixed_audio_paths)):
            if not clip or not Path(clip).exists():
                continue

            if audio and Path(audio).exists():
                output = str(episode_dir / f"scene_{i:03d}.mp4")
                result = await ffmpeg_composer.mux_video_audio(clip, audio, output)
                if result.get("success"):
                    assembled_scenes.append(result["path"])
                else:
                    assembled_scenes.append(clip)
            else:
                assembled_scenes.append(clip)

            _progress(6, f"Scene {i+1}/{len(scenes)}", (i + 1) / len(scenes) * 100)

        # ── Phase 7: Final concatenation ─────────────────────────
        _progress(7, "Concatenating final video...")
        if not assembled_scenes:
            return {"success": False, "error": "No assembled scenes to concatenate"}

        raw_output = str(episode_dir / "raw.mp4")
        concat_result = await ffmpeg_composer.concat_videos(
            assembled_scenes, raw_output, transition="fade", transition_duration=0.5,
        )
        if not concat_result.get("success"):
            # Fallback: simple concat without transitions
            concat_result = await ffmpeg_composer.concat_videos(
                assembled_scenes, raw_output,
            )

        if not concat_result.get("success"):
            return {"success": False, "error": concat_result.get("error", "Concat failed")}

        final_path = raw_output

        # ── Phase 8: Post-processing (upscale + interpolation) ───
        if quality != "draft":
            _progress(8, "Post-processing (upscale)...")
            upscale_result = await local_inference.run_inference("upscale_video", {
                "video_path": final_path,
                "output_dir": str(episode_dir),
            })
            if upscale_result.get("success") and upscale_result.get("path"):
                final_path = upscale_result["path"]
        else:
            _progress(8, "Skipping post-processing (draft mode)")

        # ── Phase 9: LUT color grading ───────────────────────────
        if color_grade:
            _progress(9, f"Applying {color_grade} color grade...")
            lut_path = Path(_HOME) / ".opencli" / "luts" / f"{color_grade}.cube"
            if lut_path.exists():
                lut_result = await ffmpeg_composer.apply_lut(
                    final_path, str(lut_path),
                    str(episode_dir / "graded.mp4"),
                )
                if lut_result.get("success"):
                    final_path = lut_result["path"]
        else:
            _progress(9, "Skipping color grading")

        # ── Phase 10: Platform encoding ──────────────────────────
        if export_platform:
            _progress(10, f"Encoding for {export_platform}...")
            encode_result = await ffmpeg_composer.encode_for_platform(
                final_path, export_platform,
                str(episode_dir / f"final_{export_platform}.mp4"),
            )
            if encode_result.get("success"):
                final_path = encode_result["path"]
        else:
            _progress(10, "Finalizing...")

        # Update episode status
        await store.update_episode_status(episode_id, "completed", 1.0, final_path)

        return {
            "success": True,
            "episode_id": episode_id,
            "output_path": final_path,
            "scenes_count": len(scenes),
            "clips_generated": len([c for c in clip_paths if c]),
            "duration_estimate": sum(s.duration_seconds for s in scenes),
        }

    except Exception as e:
        await store.update_episode_status(episode_id, "failed", 0, "")
        return {"success": False, "error": str(e)}
