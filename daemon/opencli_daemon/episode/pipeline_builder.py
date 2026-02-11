"""Build a PipelineDefinition from an EpisodeScript.

Each scene generates a sub-graph of nodes (keyframe, video, tts, assembly).
Post-processing nodes run after all scenes complete.
"""

import uuid
from typing import Any

from opencli_daemon.pipeline.definition import (
    PipelineDefinition,
    PipelineNode,
    PipelineEdge,
    PipelineParam,
)
from .script import EpisodeScript


def build_episode_pipeline(
    episode_id: str,
    script: EpisodeScript,
    settings: dict[str, Any] | None = None,
) -> PipelineDefinition:
    """Generate a pipeline definition from an episode script + settings."""
    settings = settings or {}
    image_model = settings.get("image_model", "animagine_xl")
    video_model = settings.get("video_model", "animatediff_v3")
    quality = settings.get("quality", "standard")
    color_grade = settings.get("color_grade", "")
    export_platform = settings.get("export_platform", "")
    use_controlnet = settings.get("use_controlnet", quality != "draft")
    controlnet_type = settings.get("controlnet_type", "lineart_anime")
    controlnet_scale = settings.get("controlnet_scale", 0.7)

    nodes: list[PipelineNode] = []
    edges: list[PipelineEdge] = []
    assembly_ids: list[str] = []

    scenes = script.scenes or []

    for i, scene in enumerate(scenes):
        prompt = scene.visual_prompt or scene.description
        y_base = i * 300

        # ── Keyframe node ───────────────────────────────────────
        kf_id = f"scene_{i}_keyframe"
        kf_width = 1280 if quality != "draft" else 512
        kf_height = 720 if quality != "draft" else 288
        nodes.append(PipelineNode(
            id=kf_id,
            type="media_local_generate_image",
            domain="media_creation",
            label=f"S{i+1} Keyframe",
            x=100, y=y_base,
            params={
                "prompt": prompt,
                "model": image_model,
                "width": kf_width,
                "height": kf_height,
            },
        ))

        # ── Video node ──────────────────────────────────────────
        vid_id = f"scene_{i}_video"
        if use_controlnet:
            vid_type = "media_local_controlnet_video"
            vid_params = {
                "prompt": prompt,
                "reference_image_base64": f"{{{{{kf_id}.image_base64}}}}",
                "control_type": controlnet_type,
                "controlnet_scale": controlnet_scale,
            }
        else:
            vid_type = "media_local_generate_video"
            vid_params = {
                "prompt": prompt,
                "image_base64": f"{{{{{kf_id}.image_base64}}}}",
                "model": video_model,
                "frames": max(8, int(scene.duration_seconds * 4)),
            }

        nodes.append(PipelineNode(
            id=vid_id,
            type=vid_type,
            domain="media_creation",
            label=f"S{i+1} Video",
            x=400, y=y_base,
            params=vid_params,
        ))
        edges.append(PipelineEdge(
            id=f"e_{kf_id}_to_{vid_id}",
            source_node=kf_id, source_port="output",
            target_node=vid_id, target_port="input",
        ))

        # ── TTS node (parallel with keyframe) ──────────────────
        tts_id = f"scene_{i}_tts"
        dialogue_text = " ".join(line.text for line in scene.dialogue) if scene.dialogue else ""
        voice = scene.dialogue[0].voice if scene.dialogue and scene.dialogue[0].voice else "zh-CN-XiaoxiaoNeural"

        if dialogue_text:
            nodes.append(PipelineNode(
                id=tts_id,
                type="media_tts_synthesize",
                domain="media_creation",
                label=f"S{i+1} TTS",
                x=100, y=y_base + 150,
                params={
                    "text": dialogue_text,
                    "voice": voice,
                    "provider": "edge_tts",
                },
            ))

        # ── Assembly node (mux video + audio) ──────────────────
        asm_id = f"assembly_{i}"
        asm_params: dict[str, Any] = {
            "video_path": f"{{{{{vid_id}.path}}}}",
        }
        if dialogue_text:
            asm_params["audio_path"] = f"{{{{{tts_id}.path}}}}"

        nodes.append(PipelineNode(
            id=asm_id,
            type="media_scene_assembly",
            domain="media_creation",
            label=f"S{i+1} Assembly",
            x=700, y=y_base,
            params=asm_params,
        ))

        # Edge: video → assembly
        edges.append(PipelineEdge(
            id=f"e_{vid_id}_to_{asm_id}",
            source_node=vid_id, source_port="output",
            target_node=asm_id, target_port="input",
        ))
        # Edge: tts → assembly (if dialogue exists)
        if dialogue_text:
            edges.append(PipelineEdge(
                id=f"e_{tts_id}_to_{asm_id}",
                source_node=tts_id, source_port="output",
                target_node=asm_id, target_port="audio",
            ))

        assembly_ids.append(asm_id)

    # ── Post-processing nodes (all scenes → concat → upscale → grade → encode) ──

    post_x = 1000
    post_y = len(scenes) * 150  # Center vertically

    # Concat all scene assemblies
    concat_id = "post_concat"
    concat_clips = [f"{{{{{aid}.path}}}}" for aid in assembly_ids]
    nodes.append(PipelineNode(
        id=concat_id,
        type="media_video_assembly",
        domain="media_creation",
        label="Concat All",
        x=post_x, y=post_y,
        params={"clips": concat_clips},
    ))
    for aid in assembly_ids:
        edges.append(PipelineEdge(
            id=f"e_{aid}_to_{concat_id}",
            source_node=aid, source_port="output",
            target_node=concat_id, target_port="input",
        ))

    prev_id = concat_id

    # Upscale (skip for draft)
    if quality != "draft":
        upscale_id = "post_upscale"
        nodes.append(PipelineNode(
            id=upscale_id,
            type="media_upscale_video",
            domain="media_creation",
            label="Upscale 4x",
            x=post_x + 250, y=post_y,
            params={"video_path": f"{{{{{prev_id}.path}}}}"},
        ))
        edges.append(PipelineEdge(
            id=f"e_{prev_id}_to_{upscale_id}",
            source_node=prev_id, source_port="output",
            target_node=upscale_id, target_port="input",
        ))
        prev_id = upscale_id

    # LUT color grading
    if color_grade:
        grade_id = "post_colorgrade"
        nodes.append(PipelineNode(
            id=grade_id,
            type="media_lut_colorgrade",
            domain="media_creation",
            label=f"Color: {color_grade}",
            x=post_x + 500, y=post_y,
            params={
                "video_path": f"{{{{{prev_id}.path}}}}",
                "lut_name": color_grade,
            },
        ))
        edges.append(PipelineEdge(
            id=f"e_{prev_id}_to_{grade_id}",
            source_node=prev_id, source_port="output",
            target_node=grade_id, target_port="input",
        ))
        prev_id = grade_id

    # Platform encoding
    if export_platform:
        encode_id = "post_encode"
        nodes.append(PipelineNode(
            id=encode_id,
            type="media_platform_encode",
            domain="media_creation",
            label=f"Encode: {export_platform}",
            x=post_x + 750, y=post_y,
            params={
                "video_path": f"{{{{{prev_id}.path}}}}",
                "platform": export_platform,
            },
        ))
        edges.append(PipelineEdge(
            id=f"e_{prev_id}_to_{encode_id}",
            source_node=prev_id, source_port="output",
            target_node=encode_id, target_port="input",
        ))

    pipeline_id = f"ep_{episode_id[:8]}"
    return PipelineDefinition(
        id=pipeline_id,
        name=f"Episode: {script.title or 'Untitled'}",
        description=f"Auto-generated pipeline for episode {episode_id} ({len(scenes)} scenes)",
        nodes=nodes,
        edges=edges,
        parameters=[
            PipelineParam(name="quality", type="string", default=quality, description="Quality tier"),
        ],
    )
