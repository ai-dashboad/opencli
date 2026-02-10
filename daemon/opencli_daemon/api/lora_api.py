"""LoRA + Recipe CRUD API.

Ported from daemon/lib/api/lora_api.dart.
"""

import time
import uuid

from fastapi import APIRouter, Request

from opencli_daemon.database import connection as db

router = APIRouter(prefix="/api/v1", tags=["lora"])


# ── LoRA Registry ────────────────────────────────────────────────────────────


@router.get("/loras")
async def list_loras(type: str | None = None) -> dict:
    if type:
        rows = await db.list_rows("lora_registry", where="type = ?", params=(type,),
                                  order_by="created_at DESC")
    else:
        rows = await db.list_rows("lora_registry", order_by="created_at DESC")
    return {"loras": rows}


@router.get("/loras/{lora_id}")
async def get_lora(lora_id: str) -> dict:
    row = await db.get_row("lora_registry", "id", lora_id)
    if row is None:
        return {"error": f"LoRA not found: {lora_id}"}
    return {"lora": row}


@router.post("/loras")
async def create_lora(request: Request) -> dict:
    body = await request.json()
    lid = body.get("id", str(uuid.uuid4()))
    now = int(time.time() * 1000)
    await db.upsert_row("lora_registry", {
        "id": lid,
        "name": body.get("name", ""),
        "type": body.get("type", "style"),
        "path": body.get("path", ""),
        "trigger_word": body.get("trigger_word", ""),
        "weight": body.get("weight", 0.7),
        "preview_base64": body.get("preview_base64"),
        "tags": body.get("tags", "[]") if isinstance(body.get("tags"), str) else str(body.get("tags", "[]")),
        "created_at": now,
    })
    return {"success": True, "id": lid}


@router.delete("/loras/{lora_id}")
async def delete_lora(lora_id: str) -> dict:
    deleted = await db.delete_row("lora_registry", "id", lora_id)
    return {"success": deleted}


# ── Generation Recipes ───────────────────────────────────────────────────────


@router.get("/recipes")
async def list_recipes() -> dict:
    rows = await db.list_rows("generation_recipes", order_by="updated_at DESC")
    return {"recipes": rows}


@router.get("/recipes/{recipe_id}")
async def get_recipe(recipe_id: str) -> dict:
    row = await db.get_row("generation_recipes", "id", recipe_id)
    if row is None:
        return {"error": f"Recipe not found: {recipe_id}"}
    return {"recipe": row}


@router.post("/recipes")
async def create_recipe(request: Request) -> dict:
    body = await request.json()
    rid = body.get("id", str(uuid.uuid4()))
    now = int(time.time() * 1000)
    await db.upsert_row("generation_recipes", {
        "id": rid,
        "name": body.get("name", ""),
        "description": body.get("description", ""),
        "image_model": body.get("image_model", "animagine_xl"),
        "video_model": body.get("video_model", "local_v3"),
        "quality": body.get("quality", "standard"),
        "lora_ids": body.get("lora_ids", "[]") if isinstance(body.get("lora_ids"), str) else str(body.get("lora_ids", "[]")),
        "controlnet_type": body.get("controlnet_type", "lineart_anime"),
        "controlnet_scale": body.get("controlnet_scale", 0.7),
        "ip_adapter_scale": body.get("ip_adapter_scale", 0.6),
        "color_grade": body.get("color_grade", ""),
        "export_platform": body.get("export_platform", ""),
        "created_at": now,
        "updated_at": now,
    })
    return {"success": True, "id": rid}


@router.delete("/recipes/{recipe_id}")
async def delete_recipe(recipe_id: str) -> dict:
    deleted = await db.delete_row("generation_recipes", "id", recipe_id)
    return {"success": deleted}
