"""Async SQLite database singleton with v3 schema (11+ tables).

Ported from daemon/lib/database/app_database.dart.
"""

import json
import os
import time
from pathlib import Path
from typing import Any

import aiosqlite

_HOME = Path(os.environ.get("HOME", "."))
DB_PATH = _HOME / ".opencli" / "opencli.db"
CURRENT_SCHEMA_VERSION = 3

_db: aiosqlite.Connection | None = None


async def get_db() -> aiosqlite.Connection:
    """Return the singleton database connection, initializing if needed."""
    global _db
    if _db is None:
        _db = await _init_db()
    return _db


async def close_db() -> None:
    global _db
    if _db is not None:
        await _db.close()
        _db = None


async def _init_db() -> aiosqlite.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    db = await aiosqlite.connect(str(DB_PATH))
    db.row_factory = aiosqlite.Row
    await db.execute("PRAGMA journal_mode=WAL")
    await db.execute("PRAGMA foreign_keys=ON")

    # Check current schema version
    version = 0
    try:
        cursor = await db.execute(
            "SELECT MAX(version) as v FROM schema_migrations"
        )
        row = await cursor.fetchone()
        if row and row[0] is not None:
            version = int(row[0])
    except Exception:
        # Table doesn't exist yet — fresh DB
        version = 0

    if version == 0:
        await _create_all_tables(db)
    else:
        if version < 2:
            await _create_episode_tables(db)
        if version < 3:
            await _create_lora_tables(db)

    await db.commit()
    print(f"[Database] Initialized at {DB_PATH}")
    return db


# ── Schema creation ──────────────────────────────────────────────────────────


async def _create_all_tables(db: aiosqlite.Connection) -> None:
    await db.executescript("""
        CREATE TABLE IF NOT EXISTS pipelines (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT DEFAULT '',
            nodes TEXT NOT NULL,
            edges TEXT NOT NULL,
            parameters TEXT DEFAULT '[]',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS paired_devices (
            device_id TEXT PRIMARY KEY,
            device_name TEXT NOT NULL,
            platform TEXT NOT NULL,
            paired_at INTEGER NOT NULL,
            last_seen INTEGER NOT NULL,
            shared_secret TEXT NOT NULL,
            permissions TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS pending_issues (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            labels TEXT DEFAULT '[]',
            fingerprint TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            reported INTEGER DEFAULT 0,
            remote_id TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_issues_fingerprint
            ON pending_issues(fingerprint);

        CREATE TABLE IF NOT EXISTS file_metadata (
            id TEXT PRIMARY KEY,
            filename TEXT NOT NULL,
            size INTEGER NOT NULL,
            content_type TEXT NOT NULL,
            checksum TEXT NOT NULL,
            uploaded_at INTEGER NOT NULL,
            metadata TEXT DEFAULT '{}'
        );
        CREATE INDEX IF NOT EXISTS idx_files_content_type
            ON file_metadata(content_type);

        CREATE TABLE IF NOT EXISTS generation_history (
            id TEXT PRIMARY KEY,
            mode TEXT NOT NULL,
            prompt TEXT NOT NULL,
            provider TEXT NOT NULL,
            style TEXT DEFAULT '',
            result_type TEXT NOT NULL,
            thumbnail TEXT,
            created_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS assets (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            url TEXT NOT NULL,
            thumbnail TEXT,
            provider TEXT,
            style TEXT,
            created_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS status_events (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            source TEXT DEFAULT '',
            content TEXT NOT NULL,
            task_type TEXT,
            status TEXT,
            result TEXT,
            created_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_events_created
            ON status_events(created_at);

        CREATE TABLE IF NOT EXISTS chat_messages (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            is_user INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            status TEXT DEFAULT 'completed',
            task_type TEXT,
            result TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_chat_timestamp
            ON chat_messages(timestamp);

        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            applied_at INTEGER NOT NULL,
            description TEXT
        );
    """)

    now = _now_ms()
    await db.execute(
        "INSERT OR IGNORE INTO schema_migrations VALUES (?, ?, ?)",
        (1, now, "Initial schema with 9 tables"),
    )

    await _create_episode_tables(db)
    await _create_lora_tables(db)


async def _create_episode_tables(db: aiosqlite.Connection) -> None:
    await db.executescript("""
        CREATE TABLE IF NOT EXISTS episodes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            synopsis TEXT DEFAULT '',
            script TEXT NOT NULL,
            status TEXT DEFAULT 'draft',
            progress REAL DEFAULT 0,
            output_path TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_episodes_status ON episodes(status);

        CREATE TABLE IF NOT EXISTS character_references (
            id TEXT PRIMARY KEY,
            episode_id TEXT,
            character_id TEXT NOT NULL,
            name TEXT NOT NULL,
            visual_description TEXT DEFAULT '',
            reference_image BLOB,
            embedding BLOB,
            default_voice TEXT DEFAULT 'zh-CN-XiaoxiaoNeural',
            created_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_charref_episode
            ON character_references(episode_id);
        CREATE INDEX IF NOT EXISTS idx_charref_character
            ON character_references(character_id);
    """)
    now = _now_ms()
    await db.execute(
        "INSERT OR IGNORE INTO schema_migrations VALUES (?, ?, ?)",
        (2, now, "Episode system: episodes + character_references tables"),
    )


async def _create_lora_tables(db: aiosqlite.Connection) -> None:
    await db.executescript("""
        CREATE TABLE IF NOT EXISTS lora_registry (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'style',
            path TEXT NOT NULL,
            trigger_word TEXT DEFAULT '',
            weight REAL DEFAULT 0.7,
            preview_base64 TEXT,
            tags TEXT DEFAULT '[]',
            created_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_lora_type ON lora_registry(type);

        CREATE TABLE IF NOT EXISTS generation_recipes (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT DEFAULT '',
            image_model TEXT DEFAULT 'animagine_xl',
            video_model TEXT DEFAULT 'local_v3',
            quality TEXT DEFAULT 'standard',
            lora_ids TEXT DEFAULT '[]',
            controlnet_type TEXT DEFAULT 'lineart_anime',
            controlnet_scale REAL DEFAULT 0.7,
            ip_adapter_scale REAL DEFAULT 0.6,
            color_grade TEXT DEFAULT '',
            export_platform TEXT DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
    """)
    now = _now_ms()
    await db.execute(
        "INSERT OR IGNORE INTO schema_migrations VALUES (?, ?, ?)",
        (3, now, "LoRA registry + generation recipes tables"),
    )


# ── Generic helpers ──────────────────────────────────────────────────────────


def _now_ms() -> int:
    return int(time.time() * 1000)


def _row_to_dict(row: aiosqlite.Row | None) -> dict | None:
    if row is None:
        return None
    return dict(row)


def _rows_to_list(rows: list[aiosqlite.Row]) -> list[dict]:
    return [dict(r) for r in rows]


# ── CRUD helpers (mirror AppDatabase methods) ────────────────────────────────


async def list_rows(
    table: str,
    *,
    where: str | None = None,
    params: tuple = (),
    order_by: str = "rowid DESC",
    limit: int = 100,
) -> list[dict]:
    db = await get_db()
    sql = f"SELECT * FROM {table}"
    if where:
        sql += f" WHERE {where}"
    sql += f" ORDER BY {order_by} LIMIT {limit}"
    cursor = await db.execute(sql, params)
    rows = await cursor.fetchall()
    return _rows_to_list(rows)


async def get_row(table: str, pk_col: str, pk_val: str) -> dict | None:
    db = await get_db()
    cursor = await db.execute(
        f"SELECT * FROM {table} WHERE {pk_col} = ?", (pk_val,)
    )
    row = await cursor.fetchone()
    return _row_to_dict(row)


async def upsert_row(table: str, data: dict) -> None:
    db = await get_db()
    cols = ", ".join(data.keys())
    placeholders = ", ".join(["?"] * len(data))
    sql = f"INSERT OR REPLACE INTO {table} ({cols}) VALUES ({placeholders})"
    await db.execute(sql, tuple(data.values()))
    await db.commit()


async def delete_row(table: str, pk_col: str, pk_val: str) -> bool:
    db = await get_db()
    cursor = await db.execute(
        f"DELETE FROM {table} WHERE {pk_col} = ?", (pk_val,)
    )
    await db.commit()
    return cursor.rowcount > 0


async def delete_all(table: str) -> None:
    db = await get_db()
    await db.execute(f"DELETE FROM {table}")
    await db.commit()


async def count_rows(table: str, where: str = "", params: tuple = ()) -> int:
    db = await get_db()
    sql = f"SELECT COUNT(*) as c FROM {table}"
    if where:
        sql += f" WHERE {where}"
    cursor = await db.execute(sql, params)
    row = await cursor.fetchone()
    return int(row[0]) if row else 0


async def raw_query(sql: str, params: tuple = ()) -> list[dict]:
    db = await get_db()
    cursor = await db.execute(sql, params)
    rows = await cursor.fetchall()
    return _rows_to_list(rows)


async def execute(sql: str, params: tuple = ()) -> None:
    db = await get_db()
    await db.execute(sql, params)
    await db.commit()


# ── Capped inserts (mirror Dart's auto-prune) ───────────────────────────────


async def insert_capped(table: str, data: dict, max_rows: int, order_col: str = "created_at") -> None:
    """Insert a row and prune oldest if table exceeds max_rows."""
    await upsert_row(table, data)
    db = await get_db()
    await db.execute(
        f"""DELETE FROM {table} WHERE id NOT IN (
            SELECT id FROM {table} ORDER BY {order_col} DESC LIMIT {max_rows}
        )"""
    )
    await db.commit()
