"""Storage REST API — history, assets, events, chat messages.

Ported from daemon/lib/api/storage_api.dart.
"""

import json
import time
from typing import Any

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from opencli_daemon.database import connection as db

router = APIRouter(prefix="/api/v1", tags=["storage"])


def _now() -> int:
    return int(time.time() * 1000)


# ── Generation History ───────────────────────────────────────────────────────


@router.get("/history")
async def list_history(limit: int = 50) -> dict:
    rows = await db.list_rows("generation_history", order_by="created_at DESC", limit=limit)
    return {"history": rows}


@router.post("/history")
async def create_history(request: Request) -> dict:
    body = await request.json()
    now = _now()
    await db.insert_capped("generation_history", {
        "id": body.get("id", f"h_{now}"),
        "mode": body.get("mode", ""),
        "prompt": body.get("prompt", ""),
        "provider": body.get("provider", ""),
        "style": body.get("style", ""),
        "result_type": body.get("result_type") or body.get("resultType", ""),
        "thumbnail": body.get("thumbnail"),
        "created_at": body.get("created_at") or body.get("timestamp", now),
    }, max_rows=50)
    return {"success": True}


@router.delete("/history/{item_id}")
async def delete_history(item_id: str) -> dict:
    await db.delete_row("generation_history", "id", item_id)
    return {"success": True}


@router.delete("/history")
async def clear_history() -> dict:
    await db.delete_all("generation_history")
    return {"success": True}


# ── Assets ───────────────────────────────────────────────────────────────────


@router.get("/assets")
async def list_assets(limit: int = 100) -> dict:
    rows = await db.list_rows("assets", order_by="created_at DESC", limit=limit)
    return {"assets": rows}


@router.post("/assets")
async def create_asset(request: Request) -> dict:
    body = await request.json()
    now = _now()
    await db.insert_capped("assets", {
        "id": body.get("id", f"asset_{now}"),
        "type": body.get("type", "image"),
        "title": body.get("title", ""),
        "url": body.get("url", ""),
        "thumbnail": body.get("thumbnail"),
        "provider": body.get("provider"),
        "style": body.get("style"),
        "created_at": body.get("created_at") or body.get("createdAt", now),
    }, max_rows=100)
    return {"success": True}


@router.delete("/assets/{item_id}")
async def delete_asset(item_id: str) -> dict:
    await db.delete_row("assets", "id", item_id)
    return {"success": True}


# ── Status Events ────────────────────────────────────────────────────────────


@router.get("/events")
async def list_events(limit: int = 100) -> dict:
    rows = await db.list_rows("status_events", order_by="created_at DESC", limit=limit)
    return {"events": rows}


@router.post("/events")
async def create_event(request: Request) -> dict:
    body = await request.json()
    now = _now()
    result = body.get("result")
    if result is not None and not isinstance(result, str):
        result = json.dumps(result)
    await db.insert_capped("status_events", {
        "id": body.get("id", f"evt_{now}"),
        "type": body.get("type", "system"),
        "source": body.get("source", ""),
        "content": body.get("content", ""),
        "task_type": body.get("task_type") or body.get("taskType"),
        "status": body.get("status"),
        "result": result,
        "created_at": body.get("created_at") or body.get("timestamp", now),
    }, max_rows=500)
    return {"success": True}


@router.get("/events/stats")
async def get_event_stats() -> dict:
    total = await db.count_rows("status_events")
    completed = await db.count_rows("status_events", "status = ?", ("completed",))
    failed = await db.count_rows("status_events", "status = ?", ("failed",))
    one_min_ago = _now() - 60_000
    recent = await db.count_rows("status_events", "created_at > ?", (one_min_ago,))
    denom = completed + failed
    success_rate = completed / denom if denom > 0 else 1.0
    return {
        "total": total,
        "completed": completed,
        "failed": failed,
        "success_rate": success_rate,
        "tasks_per_min": recent,
    }


# ── Chat Messages ────────────────────────────────────────────────────────────


@router.get("/chat-messages")
async def list_chat_messages_compat(limit: int = 100) -> dict:
    """Compat alias for /chat/messages."""
    return await list_chat_messages(limit)


@router.get("/chat/messages")
async def list_chat_messages(limit: int = 100) -> dict:
    rows = await db.list_rows("chat_messages", order_by="timestamp DESC", limit=limit)
    return {"messages": rows}


@router.post("/chat/messages")
async def create_chat_message(request: Request) -> dict:
    body = await request.json()
    now = _now()
    result = body.get("result")
    if result is not None and not isinstance(result, str):
        result = json.dumps(result)
    is_user = body.get("is_user") or body.get("isUser", False)
    await db.insert_capped("chat_messages", {
        "id": body.get("id", f"msg_{now}"),
        "content": body.get("content", ""),
        "is_user": 1 if is_user else 0,
        "timestamp": body.get("timestamp", now),
        "status": body.get("status", "completed"),
        "task_type": body.get("task_type") or body.get("taskType"),
        "result": result,
    }, max_rows=100, order_col="timestamp")
    return {"success": True}


@router.delete("/chat/messages")
async def clear_chat_messages() -> dict:
    await db.delete_all("chat_messages")
    return {"success": True}
