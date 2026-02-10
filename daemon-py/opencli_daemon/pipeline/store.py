"""Pipeline store — SQLite CRUD.

Ported from daemon/lib/pipeline/pipeline_store.dart.
"""

import json
import time
from typing import Any

from .definition import PipelineDefinition
from opencli_daemon.database import connection as db


async def list_pipelines() -> list[dict]:
    rows = await db.list_rows("pipelines", order_by="updated_at DESC", limit=100)
    results = []
    for row in rows:
        p = _row_to_pipeline(row)
        results.append(p.to_summary())
    return results


async def get_pipeline(pipeline_id: str) -> PipelineDefinition | None:
    row = await db.get_row("pipelines", "id", pipeline_id)
    if row is None:
        return None
    return _row_to_pipeline(row)


async def save_pipeline(pipeline: PipelineDefinition) -> None:
    now = int(time.time() * 1000)
    await db.upsert_row("pipelines", {
        "id": pipeline.id,
        "name": pipeline.name,
        "description": pipeline.description,
        "nodes": json.dumps([n.to_json() for n in pipeline.nodes]),
        "edges": json.dumps([e.to_json() for e in pipeline.edges]),
        "parameters": json.dumps([p.to_json() for p in pipeline.parameters]),
        "created_at": int(pipeline.created_at.timestamp() * 1000),
        "updated_at": now,
    })


async def delete_pipeline(pipeline_id: str) -> bool:
    return await db.delete_row("pipelines", "id", pipeline_id)


def _row_to_pipeline(row: dict) -> PipelineDefinition:
    return PipelineDefinition.from_json({
        "id": row["id"],
        "name": row["name"],
        "description": row.get("description", ""),
        "nodes": json.loads(row["nodes"]) if isinstance(row["nodes"], str) else row["nodes"],
        "edges": json.loads(row["edges"]) if isinstance(row["edges"], str) else row["edges"],
        "parameters": json.loads(row.get("parameters", "[]"))
            if isinstance(row.get("parameters"), str) else row.get("parameters", []),
    })
