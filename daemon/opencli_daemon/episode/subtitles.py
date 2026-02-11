"""ASS subtitle generation for episode scenes.

Ported from daemon/lib/episode/subtitle_generator.dart.
"""

import os
from pathlib import Path

from .script import EpisodeScene


def _format_time(seconds: float) -> str:
    """Format seconds to ASS time format: H:MM:SS.cs"""
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    cs = int((seconds % 1) * 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def generate_ass(
    scenes: list[EpisodeScene],
    output_path: str,
    *,
    font_name: str = "Arial",
    font_size: int = 24,
    margin_v: int = 20,
) -> str:
    """Generate an ASS subtitle file from episode scenes."""
    header = f"""[Script Info]
Title: OpenCLI Episode Subtitles
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,{font_name},{font_size},&H00FFFFFF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,1,2,10,10,{margin_v},1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    events = []
    current_time = 0.0

    for scene in scenes:
        if not scene.dialogue:
            current_time += scene.duration_seconds
            continue

        time_per_line = scene.duration_seconds / max(len(scene.dialogue), 1)

        for line in scene.dialogue:
            start = _format_time(current_time)
            end = _format_time(current_time + time_per_line)
            # Escape special chars for ASS
            text = line.text.replace("\\", "\\\\").replace("\n", "\\N")
            events.append(f"Dialogue: 0,{start},{end},Default,,0,0,0,,{text}")
            current_time += time_per_line

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(header)
        f.write("\n".join(events))
        f.write("\n")

    return output_path
