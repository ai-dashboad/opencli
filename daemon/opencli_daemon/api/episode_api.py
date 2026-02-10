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
    return {"episode": ep}


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

    # Run in background
    async def _run():
        try:
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

            from opencli_daemon.api.websocket_manager import ws_manager
            await ws_manager.broadcast({
                "type": "task_update",
                "task_type": "episode_generate",
                "task_id": episode_id,
                "status": "completed" if result.get("success") else "failed",
                "result": result,
            })
        finally:
            _running_generations.pop(episode_id, None)

    asyncio.create_task(_run())
    return {"success": True, "message": "Generation started", "episode_id": episode_id}


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
