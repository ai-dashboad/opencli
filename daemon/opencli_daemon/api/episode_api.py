"""Episode REST API — CRUD + generate + progress + cancel + assets.

Ported from daemon/lib/episode/episode_api.dart.
"""

import asyncio
import json
import os
import time
import uuid
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Request

from opencli_daemon.episode import store, generator
from opencli_daemon.episode.script import EpisodeScript
from opencli_daemon.episode.pipeline_builder import build_episode_pipeline
from opencli_daemon.pipeline import store as pipeline_store
from opencli_daemon.pipeline import executor as pipeline_executor

router = APIRouter(prefix="/api/v1", tags=["episodes"])

# Track running generation tasks for cancellation
_running_generations: dict[str, bool] = {}  # episode_id -> cancelled


@router.get("/episodes")
async def list_episodes(limit: int = 50) -> dict:
    episodes = await store.list_episodes(limit)
    return {"episodes": episodes}


@router.post("/episodes/from-script")
async def create_from_script(request: Request) -> dict:
    """Create an episode directly from a structured script (no Ollama generation)."""
    body = await request.json()
    script_data = body.get("script", {})
    eid = str(uuid.uuid4())

    await store.save_episode({
        "id": eid,
        "title": script_data.get("title", "Untitled"),
        "synopsis": script_data.get("narrative", ""),
        "script": json.dumps(script_data) if isinstance(script_data, dict) else script_data,
        "status": "draft",
        "progress": 0,
    })
    return {"success": True, "id": eid}


@router.get("/episodes/{episode_id}")
async def get_episode(episode_id: str) -> dict:
    episode = await store.get_episode(episode_id)
    if episode is None:
        return {"error": f"Episode not found: {episode_id}"}

    # Parse script JSON
    ep = dict(episode)
    if isinstance(ep.get("script"), str):
        try:
            ep["script"] = json.loads(ep["script"])
        except Exception:
            pass
    return {"success": True, "episode": ep}


@router.post("/episodes")
async def create_episode(request: Request) -> dict:
    body = await request.json()
    eid = body.get("id", str(uuid.uuid4()))
    script = body.get("script", {"title": body.get("title", ""), "scenes": []})

    await store.save_episode({
        "id": eid,
        "title": body.get("title", "Untitled"),
        "synopsis": body.get("synopsis", ""),
        "script": json.dumps(script) if isinstance(script, dict) else script,
        "status": "draft",
        "progress": 0,
    })
    return {"success": True, "id": eid}


@router.put("/episodes/{episode_id}")
async def update_episode(episode_id: str, request: Request) -> dict:
    body = await request.json()
    body["id"] = episode_id
    if "script" in body and isinstance(body["script"], dict):
        body["script"] = json.dumps(body["script"])
    await store.save_episode(body)
    return {"success": True}


@router.delete("/episodes/{episode_id}")
async def delete_episode(episode_id: str) -> dict:
    deleted = await store.delete_episode(episode_id)
    return {"success": deleted}


@router.post("/episodes/{episode_id}/generate")
async def generate_episode(episode_id: str, request: Request) -> dict:
    body = await request.json() if await request.body() else {}

    episode = await store.get_episode(episode_id)
    if episode is None:
        return {"success": False, "error": "Episode not found"}

    script_data = episode.get("script", "{}")
    if isinstance(script_data, str):
        script_data = json.loads(script_data)
    script = EpisodeScript.from_json(script_data)

    # Mark as generating
    _running_generations[episode_id] = False

    async def _on_progress(data: dict) -> None:
        from opencli_daemon.api.websocket_manager import ws_manager
        await ws_manager.broadcast({
            "type": "task_update",
            "task_type": "episode_generate",
            "task_id": episode_id,
            "status": "running",
            **data,
        })

    # Check if this episode has an associated pipeline
    pipeline_id = episode.get("pipeline_id")
    use_pipeline = body.get("use_pipeline", True) and pipeline_id

    # Run in background
    async def _run():
        try:
            if use_pipeline:
                result = await _run_via_pipeline(
                    episode_id, pipeline_id, body, _on_progress,
                )
            else:
                result = await generator.generate_episode(
                    episode_id, script,
                    on_progress=_on_progress,
                    image_model=body.get("image_model", "animagine_xl"),
                    video_model=body.get("video_model", "animatediff_v3"),
                    quality=body.get("quality", "standard"),
                    color_grade=body.get("color_grade", ""),
                    export_platform=body.get("export_platform", ""),
                    cancelled=lambda: _running_generations.get(episode_id, False),
                )

            # Ensure DB status is updated (fallback if generator's own update failed)
            final_status = "completed" if result.get("success") else "failed"
            try:
                await store.update_episode_status(
                    episode_id, final_status,
                    1.0 if result.get("success") else 0,
                    result.get("output_path", ""),
                )
            except Exception:
                pass

            from opencli_daemon.api.websocket_manager import ws_manager
            await ws_manager.broadcast({
                "type": "task_update",
                "task_type": "episode_generate",
                "task_id": episode_id,
                "status": final_status,
                "result": result,
            })
        except Exception as e:
            # Generation crashed — mark as failed
            try:
                await store.update_episode_status(episode_id, "failed", 0, "")
            except Exception:
                pass
        finally:
            _running_generations.pop(episode_id, None)

    asyncio.create_task(_run())
    return {"success": True, "message": "Generation started", "episode_id": episode_id}


async def _run_via_pipeline(
    episode_id: str,
    pipeline_id: str,
    body: dict,
    on_progress,
) -> dict:
    """Execute episode generation via the pipeline executor."""
    pipeline = await pipeline_store.get_pipeline(pipeline_id)
    if pipeline is None:
        return {"success": False, "error": f"Pipeline {pipeline_id} not found"}

    from opencli_daemon.domains.registry import get_registry

    # Map pipeline progress → episode progress format
    total_nodes = len(pipeline.nodes)

    async def _pipeline_progress(data: dict):
        node_id = data.get("node_id", "")
        pct = data.get("progress", 0)
        # Map node_id prefix to phase name
        if node_id.startswith("scene_") and node_id.endswith("_keyframe"):
            phase_name = "Keyframe Generation"
        elif node_id.startswith("scene_") and node_id.endswith("_video"):
            phase_name = "Video Animation"
        elif node_id.startswith("scene_") and node_id.endswith("_tts"):
            phase_name = "TTS Synthesis"
        elif node_id.startswith("assembly_"):
            phase_name = "Scene Assembly"
        elif node_id.startswith("post_"):
            phase_name = "Post-Processing"
        else:
            phase_name = node_id

        await on_progress({
            "progress": pct,
            "status_message": f"{phase_name}: {node_id} ({data.get('node_status', '')})",
            "node_id": node_id,
            "node_status": data.get("node_status", ""),
        })

    registry = get_registry()
    result = await pipeline_executor.execute_pipeline(
        pipeline,
        registry,
        override_params=body.get("params"),
        on_progress=_pipeline_progress,
        cancelled=lambda: _running_generations.get(episode_id, False),
    )

    # Update episode status based on pipeline result
    if result.get("success"):
        # Find the final output path from the last node
        node_results = result.get("node_results", {})
        final_path = ""
        for nid in ["post_encode", "post_colorgrade", "post_upscale", "post_concat"]:
            if nid in node_results and node_results[nid].get("path"):
                final_path = node_results[nid]["path"]
                break
        await store.update_episode_status(episode_id, "completed", 1.0, final_path)
    else:
        await store.update_episode_status(episode_id, "failed", 0, "")

    return result


@router.post("/episodes/{episode_id}/build-pipeline")
async def build_pipeline(episode_id: str, request: Request) -> dict:
    """Generate a pipeline from the episode script + settings."""
    body = await request.json() if await request.body() else {}

    episode = await store.get_episode(episode_id)
    if episode is None:
        return {"success": False, "error": "Episode not found"}

    script_data = episode.get("script", "{}")
    if isinstance(script_data, str):
        script_data = json.loads(script_data)
    script = EpisodeScript.from_json(script_data)

    pipeline = build_episode_pipeline(episode_id, script, settings=body)
    await pipeline_store.save_pipeline(pipeline)

    # Link pipeline to episode
    from opencli_daemon.database import connection as db
    await db.execute(
        "UPDATE episodes SET pipeline_id = ? WHERE id = ?",
        (pipeline.id, episode_id),
    )

    return {"success": True, "pipeline_id": pipeline.id, "pipeline": pipeline.to_json()}


@router.get("/episodes/{episode_id}/pipeline")
async def get_episode_pipeline(episode_id: str) -> dict:
    """Get the pipeline associated with an episode."""
    episode = await store.get_episode(episode_id)
    if episode is None:
        return {"success": False, "error": "Episode not found"}

    pipeline_id = episode.get("pipeline_id")
    if not pipeline_id:
        return {"success": True, "pipeline": None}

    pipeline = await pipeline_store.get_pipeline(pipeline_id)
    if pipeline is None:
        return {"success": True, "pipeline": None}

    return {"success": True, "pipeline_id": pipeline.id, "pipeline": pipeline.to_json()}


@router.post("/episodes/{episode_id}/apply-template")
async def apply_template(episode_id: str, request: Request) -> dict:
    """Apply a pipeline template to an episode."""
    body = await request.json()
    template_id = body.get("template_id", "")

    episode = await store.get_episode(episode_id)
    if episode is None:
        return {"success": False, "error": "Episode not found"}

    # Load template
    templates_dir = Path(__file__).parent.parent.parent.parent / "capabilities" / "pipeline-templates"
    template_file = templates_dir / f"{template_id}.json"
    if not template_file.exists():
        return {"success": False, "error": f"Template not found: {template_id}"}

    with open(template_file) as f:
        template_data = json.load(f)

    from opencli_daemon.pipeline.definition import PipelineDefinition
    # Generate unique pipeline ID
    pipeline_id = f"ep_{episode_id[:8]}"
    template_data["id"] = pipeline_id
    template_data["name"] = f"Episode: {episode.get('title', 'Untitled')} ({template_id})"

    pipeline = PipelineDefinition.from_json(template_data)
    await pipeline_store.save_pipeline(pipeline)

    from opencli_daemon.database import connection as db
    await db.execute(
        "UPDATE episodes SET pipeline_id = ? WHERE id = ?",
        (pipeline_id, episode_id),
    )

    return {"success": True, "pipeline_id": pipeline_id, "pipeline": pipeline.to_json()}


@router.get("/pipeline-templates")
async def list_pipeline_templates() -> dict:
    """List available pipeline templates."""
    templates_dir = Path(__file__).parent.parent.parent.parent / "capabilities" / "pipeline-templates"
    templates = []
    if templates_dir.exists():
        for f in sorted(templates_dir.iterdir()):
            if f.suffix == ".json":
                try:
                    with open(f) as fp:
                        data = json.load(fp)
                    templates.append({
                        "id": f.stem,
                        "name": data.get("name", f.stem),
                        "description": data.get("description", ""),
                        "node_count": len(data.get("nodes", [])),
                    })
                except Exception as e:
                    print(f"[EpisodeApi] Warning: failed to parse template {f.name}: {e}")
    return {"templates": templates}


@router.post("/episodes/{episode_id}/cancel")
async def cancel_generation(episode_id: str) -> dict:
    if episode_id in _running_generations:
        _running_generations[episode_id] = True
        return {"success": True, "message": "Cancellation requested"}
    return {"success": False, "error": "No active generation"}


@router.get("/episodes/{episode_id}/progress")
async def get_progress(episode_id: str) -> dict:
    episode = await store.get_episode(episode_id)
    if episode is None:
        return {"error": "Episode not found"}
    return {
        "status": episode.get("status", "unknown"),
        "progress": episode.get("progress", 0),
    }


@router.get("/episodes/{episode_id}/assets")
async def get_assets(episode_id: str) -> dict:
    """List intermediate assets (keyframes, clips, audio, subtitles)."""
    asset_dir = Path(os.environ.get("HOME", ".")) / ".opencli" / "output" / "episodes" / episode_id
    if not asset_dir.exists():
        return {"assets": []}

    assets = []
    for f in sorted(asset_dir.iterdir()):
        if f.is_file():
            assets.append({
                "name": f.name,
                "path": str(f),
                "size": f.stat().st_size,
                "type": f.suffix.lstrip("."),
            })
    return {"assets": assets}


@router.post("/episodes/batch-generate")
async def batch_generate(request: Request) -> dict:
    body = await request.json()
    episode_ids = body.get("episode_ids", [])
    results = []
    for eid in episode_ids:
        # Generate sequentially to avoid OOM
        episode = await store.get_episode(eid)
        if episode is None:
            results.append({"id": eid, "success": False, "error": "Not found"})
            continue
        results.append({"id": eid, "success": True, "status": "queued"})
    return {"success": True, "results": results}


# ── Character endpoints ──────────────────────────────────────────────────

@router.get("/episodes/{episode_id}/characters")
async def list_characters(episode_id: str) -> dict:
    chars = await store.list_characters(episode_id)
    return {"characters": chars}


@router.post("/episodes/{episode_id}/characters")
async def create_character(episode_id: str, request: Request) -> dict:
    body = await request.json()
    char_id = body.get("id", str(uuid.uuid4()))
    await store.save_character({
        "id": char_id,
        "episode_id": episode_id,
        "character_id": body.get("character_id", char_id),
        "name": body.get("name", ""),
        "visual_description": body.get("visual_description", ""),
        "default_voice": body.get("default_voice", "zh-CN-XiaoxiaoNeural"),
    })
    return {"success": True, "id": char_id}


@router.delete("/characters/{char_id}")
async def delete_character(char_id: str) -> dict:
    deleted = await store.delete_character(char_id)
    return {"success": deleted}
