"""Pipeline executor — Kahn's algorithm with parallel node execution.

Ported from daemon/lib/pipeline/pipeline_executor.dart.
"""

import asyncio
import time
from enum import Enum
from typing import Any, Callable

from .definition import PipelineDefinition, resolve_variables


class NodeStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"


ProgressCallback = Callable[[dict[str, Any]], None]


async def execute_pipeline(
    pipeline: PipelineDefinition,
    domain_registry: Any,
    override_params: dict[str, Any] | None = None,
    on_progress: ProgressCallback | None = None,
) -> dict[str, Any]:
    """Execute a pipeline DAG with topological ordering and parallel execution."""
    start_time = time.time()
    params = {p.name: p.default for p in pipeline.parameters}
    if override_params:
        params.update(override_params)

    node_results: dict[str, dict] = {}
    node_statuses: dict[str, NodeStatus] = {n.id: NodeStatus.PENDING for n in pipeline.nodes}
    node_map = {n.id: n for n in pipeline.nodes}

    # Build adjacency for Kahn's algorithm
    in_degree: dict[str, int] = {n.id: 0 for n in pipeline.nodes}
    dependents: dict[str, list[str]] = {n.id: [] for n in pipeline.nodes}

    for edge in pipeline.edges:
        in_degree[edge.target_node] = in_degree.get(edge.target_node, 0) + 1
        dependents.setdefault(edge.source_node, []).append(edge.target_node)

    # Cycle detection
    visited: set[str] = set()
    temp: set[str] = set()
    for n in pipeline.nodes:
        if _has_cycle(n.id, dependents, visited, temp):
            return {"success": False, "error": "Pipeline contains a cycle"}

    # BFS execution (Kahn's algorithm)
    queue = [n.id for n in pipeline.nodes if in_degree[n.id] == 0]
    completed_count = 0
    total = len(pipeline.nodes)

    while queue:
        current_level = list(queue)
        queue.clear()

        # Execute all nodes in current level in parallel
        tasks = []
        for nid in current_level:
            tasks.append(_execute_node(
                nid, node_map, domain_registry, node_results, node_statuses, params
            ))

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Process results and enqueue dependents
        for i, nid in enumerate(current_level):
            if isinstance(results[i], Exception):
                node_statuses[nid] = NodeStatus.FAILED
                node_results[nid] = {"success": False, "error": str(results[i])}
            completed_count += 1

            if on_progress:
                on_progress({
                    "pipeline_id": pipeline.id,
                    "node_id": nid,
                    "node_status": node_statuses[nid].value,
                    "progress": int(completed_count / total * 100),
                })

            # Enqueue dependents whose in-degree drops to 0
            for dep_id in dependents.get(nid, []):
                in_degree[dep_id] -= 1
                if in_degree[dep_id] <= 0:
                    # Skip if any dependency failed
                    dep_sources = [e.source_node for e in pipeline.edges if e.target_node == dep_id]
                    if any(node_statuses.get(s) == NodeStatus.FAILED for s in dep_sources):
                        node_statuses[dep_id] = NodeStatus.SKIPPED
                        node_results[dep_id] = {"success": False, "skipped": True}
                    else:
                        queue.append(dep_id)

    elapsed = time.time() - start_time
    failed = [nid for nid, s in node_statuses.items() if s == NodeStatus.FAILED]
    skipped = [nid for nid, s in node_statuses.items() if s == NodeStatus.SKIPPED]

    return {
        "success": len(failed) == 0,
        "pipeline_id": pipeline.id,
        "node_results": node_results,
        "node_statuses": {k: v.value for k, v in node_statuses.items()},
        "failed_nodes": failed,
        "skipped_nodes": skipped,
        "duration_ms": int(elapsed * 1000),
    }


async def _execute_node(
    node_id: str,
    node_map: dict,
    registry: Any,
    node_results: dict,
    node_statuses: dict,
    params: dict,
) -> None:
    """Execute a single pipeline node."""
    node = node_map[node_id]
    node_statuses[node_id] = NodeStatus.RUNNING

    # Resolve variable references in params
    resolved_params = {}
    for k, v in node.params.items():
        resolved_params[k] = resolve_variables(v, node_results, params) if isinstance(v, str) else v

    try:
        result = await registry.execute_task(node.type, resolved_params)
        node_results[node_id] = result
        node_statuses[node_id] = NodeStatus.COMPLETED if result.get("success") else NodeStatus.FAILED
    except Exception as e:
        node_results[node_id] = {"success": False, "error": str(e)}
        node_statuses[node_id] = NodeStatus.FAILED


def _has_cycle(node_id: str, dependents: dict, visited: set, temp: set) -> bool:
    if node_id in temp:
        return True
    if node_id in visited:
        return False
    temp.add(node_id)
    for dep in dependents.get(node_id, []):
        if _has_cycle(dep, dependents, visited, temp):
            return True
    temp.discard(node_id)
    visited.add(node_id)
    return False
