"""Pipeline REST API — CRUD + execute + node catalog.

Ported from daemon/lib/pipeline/pipeline_api.dart.
"""

import json
import time
import uuid
from typing import Any

from fastapi import APIRouter, Request

from opencli_daemon.pipeline import store, executor
from opencli_daemon.pipeline.definition import PipelineDefinition

router = APIRouter(prefix="/api/v1", tags=["pipelines"])


@router.get("/pipelines")
async def list_pipelines() -> dict:
    pipelines = await store.list_pipelines()
    return {"pipelines": pipelines}


@router.get("/pipelines/{pipeline_id}")
async def get_pipeline(pipeline_id: str) -> dict:
    pipeline = await store.get_pipeline(pipeline_id)
    if pipeline is None:
        return {"error": f"Pipeline not found: {pipeline_id}"}
    return {"pipeline": pipeline.to_json()}


@router.post("/pipelines")
async def create_pipeline(request: Request) -> dict:
    body = await request.json()
    pid = body.get("id", str(uuid.uuid4()))
    body["id"] = pid
    pipeline = PipelineDefinition.from_json(body)
    await store.save_pipeline(pipeline)
    return {"success": True, "id": pid, "pipeline": pipeline.to_json()}


@router.put("/pipelines/{pipeline_id}")
async def update_pipeline(pipeline_id: str, request: Request) -> dict:
    body = await request.json()
    body["id"] = pipeline_id
    pipeline = PipelineDefinition.from_json(body)
    await store.save_pipeline(pipeline)
    return {"success": True, "pipeline": pipeline.to_json()}


@router.delete("/pipelines/{pipeline_id}")
async def delete_pipeline(pipeline_id: str) -> dict:
    deleted = await store.delete_pipeline(pipeline_id)
    return {"success": deleted}


@router.post("/pipelines/{pipeline_id}/run")
async def run_pipeline(pipeline_id: str, request: Request) -> dict:
    body = await request.json() if await request.body() else {}
    override_params = body.get("parameters", {})

    pipeline = await store.get_pipeline(pipeline_id)
    if pipeline is None:
        return {"success": False, "error": f"Pipeline not found: {pipeline_id}"}

    from opencli_daemon.api.unified_server import app
    registry = app.state.domain_registry

    result = await executor.execute_pipeline(
        pipeline, registry, override_params=override_params,
    )
    return result


@router.get("/nodes/video-catalog")
async def get_video_node_catalog() -> dict:
    """Static video editing node catalog for the visual pipeline editor."""
    catalog = [
        # ── Input ──
        {"type": "load_model", "category": "input", "name": "Load Model",
         "description": "Select an AI video generation provider and model", "icon": "\u2295", "color": 0xFF4CAF50,
         "inputs": [
             {"name": "provider", "type": "string", "inputType": "select",
              "options": ["Flux", "Runway", "Kling", "Luma"], "defaultValue": "Flux"},
             {"name": "model", "type": "string", "inputType": "select",
              "options": ["Flux Dev", "Flux Pro", "Flux Schnell"], "defaultValue": "Flux Dev"},
         ], "outputs": [{"name": "model", "type": "model"}]},
        {"type": "prompt", "category": "input", "name": "Prompt",
         "description": "Text prompt describing the desired video content", "icon": "\u270E", "color": 0xFF4CAF50,
         "inputs": [{"name": "prompt", "type": "string", "inputType": "textarea"}],
         "outputs": [{"name": "text", "type": "string"}]},
        {"type": "load_image", "category": "input", "name": "Load Image",
         "description": "Load a reference image from a file path or URL", "icon": "\u2B12", "color": 0xFF4CAF50,
         "inputs": [{"name": "path", "type": "string", "inputType": "text"}],
         "outputs": [{"name": "image", "type": "image"}]},
        {"type": "number", "category": "input", "name": "Number",
         "description": "A numeric constant value", "icon": "#", "color": 0xFF4CAF50,
         "inputs": [
             {"name": "value", "type": "number", "inputType": "text"},
             {"name": "label", "type": "string", "inputType": "text"},
         ], "outputs": [{"name": "value", "type": "number"}]},
        # ── Process ──
        {"type": "generate", "category": "process", "name": "Generate",
         "description": "Generate a video from a model, prompt, and optional reference image", "icon": "\u2731", "color": 0xFF2196F3,
         "inputs": [
             {"name": "model", "type": "model"}, {"name": "prompt", "type": "string"},
             {"name": "image", "type": "image", "required": False},
             {"name": "steps", "type": "number", "inputType": "slider", "min": 1, "max": 150, "defaultValue": 30},
             {"name": "duration", "type": "number", "inputType": "slider", "min": 1, "max": 30, "defaultValue": 5},
             {"name": "seed", "type": "number", "inputType": "text"},
         ], "outputs": [{"name": "video", "type": "video"}]},
        {"type": "concat", "category": "process", "name": "Concatenate",
         "description": "Join two video clips sequentially with an optional transition", "icon": "\u229E", "color": 0xFF2196F3,
         "inputs": [
             {"name": "video_a", "type": "video"}, {"name": "video_b", "type": "video"},
             {"name": "transition", "type": "string", "inputType": "select",
              "options": ["none", "fade", "wipe", "dissolve"], "defaultValue": "none"},
         ], "outputs": [{"name": "video", "type": "video"}]},
        {"type": "blend", "category": "process", "name": "Blend",
         "description": "Blend two video clips together using a compositing mode", "icon": "\u25D1", "color": 0xFF2196F3,
         "inputs": [
             {"name": "video_a", "type": "video"}, {"name": "video_b", "type": "video"},
             {"name": "ratio", "type": "number", "inputType": "slider", "min": 0.0, "max": 1.0, "defaultValue": 0.5},
             {"name": "mode", "type": "string", "inputType": "select",
              "options": ["overlay", "multiply", "screen", "add"], "defaultValue": "overlay"},
         ], "outputs": [{"name": "video", "type": "video"}]},
        {"type": "adjust", "category": "process", "name": "Adjust",
         "description": "Adjust brightness, contrast, and saturation of a video", "icon": "\u25D0", "color": 0xFF2196F3,
         "inputs": [
             {"name": "video", "type": "video"},
             {"name": "brightness", "type": "number", "inputType": "slider", "min": -1.0, "max": 1.0, "defaultValue": 0.0},
             {"name": "contrast", "type": "number", "inputType": "slider", "min": 0.0, "max": 3.0, "defaultValue": 1.0},
             {"name": "saturation", "type": "number", "inputType": "slider", "min": 0.0, "max": 3.0, "defaultValue": 1.0},
         ], "outputs": [{"name": "video", "type": "video"}]},
        {"type": "upscale", "category": "process", "name": "Upscale",
         "description": "Upscale video resolution", "icon": "\u21F1", "color": 0xFF2196F3,
         "inputs": [
             {"name": "video", "type": "video"},
             {"name": "scale", "type": "string", "inputType": "select", "options": ["2x", "4x"], "defaultValue": "2x"},
             {"name": "method", "type": "string", "inputType": "select",
              "options": ["lanczos", "bicubic", "bilinear"], "defaultValue": "lanczos"},
         ], "outputs": [{"name": "video", "type": "video"}]},
        {"type": "style_transfer", "category": "process", "name": "Style Transfer",
         "description": "Apply a cinematic style preset to a video", "icon": "\u2756", "color": 0xFF2196F3,
         "inputs": [
             {"name": "video", "type": "video"},
             {"name": "preset", "type": "string", "inputType": "select",
              "options": ["cinematic", "adPromo", "socialMedia", "calmAesthetic", "epic", "mysterious"],
              "defaultValue": "cinematic"},
         ], "outputs": [{"name": "video", "type": "video"}]},
        {"type": "controlnet", "category": "process", "name": "ControlNet",
         "description": "Extract control signals from a reference image", "icon": "\u2316", "color": 0xFF9E9E9E, "placeholder": True,
         "inputs": [
             {"name": "image", "type": "image"},
             {"name": "type", "type": "string", "inputType": "select",
              "options": ["pose", "depth", "edge", "canny"], "defaultValue": "pose"},
         ], "outputs": [{"name": "control", "type": "control"}]},
        {"type": "ip_adapter", "category": "process", "name": "IP-Adapter",
         "description": "Generate an image embedding from a reference image", "icon": "\u229B", "color": 0xFF9E9E9E, "placeholder": True,
         "inputs": [
             {"name": "ref_image", "type": "image"},
             {"name": "strength", "type": "number", "inputType": "slider", "min": 0.0, "max": 1.0, "defaultValue": 0.75},
         ], "outputs": [{"name": "embedding", "type": "embedding"}]},
        # ── Audio ──
        {"type": "tts_synthesize", "category": "audio", "name": "Text-to-Speech",
         "description": "Generate spoken audio from text using Edge TTS or ElevenLabs", "icon": "\U0001F5E3", "color": 0xFF4CAF50,
         "inputs": [
             {"name": "text", "type": "string", "inputType": "textarea", "required": True},
             {"name": "voice", "type": "string", "inputType": "select",
              "options": ["zh-CN-XiaoxiaoNeural", "zh-CN-YunxiNeural", "ja-JP-NanamiNeural", "en-US-JennyNeural"],
              "defaultValue": "zh-CN-XiaoxiaoNeural"},
             {"name": "rate", "type": "number", "inputType": "slider", "min": 0.5, "max": 2.0, "defaultValue": 1.0},
         ], "outputs": [{"name": "audio", "type": "audio"}, {"name": "file_path", "type": "string"}]},
        {"type": "audio_mix", "category": "audio", "name": "Audio Mix",
         "description": "Mix voice audio with background music", "icon": "\U0001F3B5", "color": 0xFF4CAF50,
         "inputs": [
             {"name": "voice", "type": "audio"}, {"name": "bgm", "type": "audio"},
             {"name": "bgm_volume", "type": "number", "inputType": "slider", "min": 0.0, "max": 1.0, "defaultValue": 0.3},
         ], "outputs": [{"name": "audio", "type": "audio"}]},
        {"type": "subtitle_overlay", "category": "process", "name": "Subtitles",
         "description": "Burn ASS/SRT subtitles onto a video", "icon": "\U0001F524", "color": 0xFF2196F3,
         "inputs": [{"name": "video", "type": "video"}, {"name": "subtitles", "type": "string", "inputType": "text"}],
         "outputs": [{"name": "video", "type": "video"}]},
        {"type": "video_assembly", "category": "output", "name": "Assemble Video",
         "description": "Concatenate video clips and mux with audio into final output", "icon": "\U0001F3AC", "color": 0xFFFF9800,
         "inputs": [
             {"name": "videos", "type": "video"}, {"name": "audio", "type": "audio", "required": False},
             {"name": "subtitles", "type": "string", "required": False},
         ], "outputs": [{"name": "video", "type": "video"}]},
        # ── Output ──
        {"type": "output", "category": "output", "name": "Output",
         "description": "Save the final video to disk in the chosen format", "icon": "\u2261", "color": 0xFFFF9800,
         "inputs": [
             {"name": "video", "type": "video"},
             {"name": "format", "type": "string", "inputType": "select",
              "options": ["mp4", "webm", "gif"], "defaultValue": "mp4"},
             {"name": "save_path", "type": "string", "inputType": "text"},
         ], "outputs": []},
    ]
    return {"success": True, "nodes": catalog, "total": len(catalog)}


@router.get("/nodes/catalog")
async def get_node_catalog() -> dict:
    """Auto-generate node catalog from domain registry."""
    from opencli_daemon.api.unified_server import app
    registry = app.state.domain_registry

    catalog: list[dict] = []
    for domain in registry.domains:
        for tt in domain.task_types:
            dc = domain.display_configs.get(tt)
            catalog.append({
                "type": tt,
                "domain": domain.id,
                "domain_name": domain.name,
                "label": dc.title_template if dc else tt.replace("_", " ").title(),
                "icon": dc.icon if dc else domain.icon,
                "color_hex": dc.color_hex if dc else domain.color_hex,
                "ports": {
                    "inputs": [{"id": "input", "label": "Input"}],
                    "outputs": [{"id": "output", "label": "Output"}],
                },
            })
    return {"catalog": catalog}
