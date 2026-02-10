"""Config API — GET/POST /api/v1/config.

Ported from unified_api_server.dart config handlers.
"""

from fastapi import APIRouter, Request

from opencli_daemon.config import load_config, save_config, deep_merge, mask_api_keys

router = APIRouter(prefix="/api/v1", tags=["config"])


@router.get("/config")
async def get_config() -> dict:
    try:
        config = load_config(resolve_env=False)
        masked = mask_api_keys(config)
        return {"config": masked}
    except Exception as e:
        return {"error": f"Failed to read config: {e}"}


@router.post("/config")
async def update_config(request: Request) -> dict:
    try:
        updates = await request.json()
        current = load_config(resolve_env=False)
        deep_merge(current, updates)
        save_config(current)
        return {"success": True, "message": "Config saved and applied."}
    except Exception as e:
        return {"error": f"Failed to update config: {e}"}
