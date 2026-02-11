"""POST /api/v1/execute — Method-based task execution.

Ported from Dart RequestRouter pattern. Routes method strings like
"calculator_eval", "calculator.calculator_eval", "system.info", "domains.list".
"""

import time
from typing import Any

from fastapi import APIRouter, Request

router = APIRouter(prefix="/api/v1", tags=["execute"])


@router.post("/execute")
async def execute_method(request: Request) -> dict:
    body = await request.json()
    method = body.get("method", "")
    params = body.get("params", [])

    # Extract params dict from list (Web UI sends params as [dict])
    task_data: dict[str, Any] = {}
    if params and isinstance(params, list) and len(params) > 0:
        if isinstance(params[0], dict):
            task_data = params[0]
    elif isinstance(params, dict):
        task_data = params

    from opencli_daemon.api.unified_server import app
    registry = app.state.domain_registry

    parts = method.split(".")
    result: Any

    try:
        # 1. Direct task type: "calculator_eval"
        if registry.handles_task_type(method):
            result = await registry.execute_task(method, task_data)

        # 2. Domain.task: "calculator.calculator_eval"
        elif len(parts) == 2 and registry.handles_task_type(parts[1]):
            result = await registry.execute_task(parts[1], task_data)

        # 3. system.* commands
        elif parts[0] == "system":
            result = _handle_system(parts[1] if len(parts) > 1 else "")

        # 4. domains.* discovery
        elif parts[0] == "domains":
            result = _handle_domains_discovery(registry, parts)

        else:
            result = {"error": f"Unknown method: {method}"}

    except Exception as e:
        result = {"error": str(e)}

    return {
        "success": "error" not in result if isinstance(result, dict) else True,
        "result": result,
        "request_id": hex(int(time.time() * 1000))[2:],
    }


def _handle_system(sub: str) -> dict:
    """Handle system.* methods."""
    import platform
    import os

    if sub == "info":
        return {
            "success": True,
            "hostname": platform.node(),
            "platform": platform.system().lower(),
            "version": "0.2.0-py",
            "python": platform.python_version(),
        }
    elif sub == "ping":
        return {"success": True, "pong": True}
    else:
        return {"error": f"Unknown system method: {sub}"}


def _handle_domains_discovery(registry: Any, parts: list[str]) -> dict:
    """Handle domains.* discovery methods."""
    if len(parts) == 1 or parts[1] == "list":
        return {
            "success": True,
            "domains": [
                {
                    "id": d.id,
                    "name": d.name,
                    "task_types": d.task_types,
                }
                for d in registry.domains
            ],
        }
    elif parts[1] == "task_types":
        return {
            "success": True,
            "task_types": registry.all_task_types,
        }
    else:
        return {"error": f"Unknown domains method: {'.'.join(parts)}"}
