"""Episode SQLite CRUD.

Ported from daemon/lib/episode/episode_store.dart.
"""

import json
import time
from typing import Any

from opencli_daemon.database import connection as db


async def list_episodes(limit: int = 50) -> list[dict]:
    return await db.list_rows("episodes", order_by="updated_at DESC", limit=limit)


async def get_episode(episode_id: str) -> dict | None:
    return await db.get_row("episodes", "id", episode_id)


async def save_episode(data: dict) -> None:
    now = int(time.time() * 1000)
    if "script" in data and not isinstance(data["script"], str):
        data["script"] = json.dumps(data["script"])
    data.setdefault("created_at", now)
    data["updated_at"] = now
    await db.upsert_row("episodes", data)


async def update_episode_status(episode_id: str, status: str, progress: float = 0, output_path: str = "") -> None:
    database = await db.get_db()
    await database.execute(
        "UPDATE episodes SET status = ?, progress = ?, output_path = ?, updated_at = ? WHERE id = ?",
        (status, progress, output_path, int(time.time() * 1000), episode_id),
    )
    await database.commit()


async def delete_episode(episode_id: str) -> bool:
    return await db.delete_row("episodes", "id", episode_id)


# Character references

async def list_characters(episode_id: str | None = None) -> list[dict]:
    if episode_id:
        return await db.list_rows("character_references", where="episode_id = ?",
                                  params=(episode_id,), order_by="created_at DESC")
    return await db.list_rows("character_references", order_by="created_at DESC", limit=100)


async def save_character(data: dict) -> None:
    now = int(time.time() * 1000)
    data.setdefault("created_at", now)
    await db.upsert_row("character_references", data)


async def delete_character(char_id: str) -> bool:
    return await db.delete_row("character_references", "id", char_id)
