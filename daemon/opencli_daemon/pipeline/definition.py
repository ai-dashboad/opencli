"""Pipeline definition data models.

Ported from daemon/lib/pipeline/pipeline_definition.dart.
"""

import json
import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any


@dataclass
class PipelineNode:
    id: str
    type: str  # task type e.g. 'weather_current'
    domain: str = ""
    label: str = ""
    x: float = 0
    y: float = 0
    params: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_json(cls, data: dict) -> "PipelineNode":
        pos = data.get("position", {})
        return cls(
            id=data["id"],
            type=data["type"],
            domain=data.get("domain", ""),
            label=data.get("label", ""),
            x=float(pos.get("x", 0)),
            y=float(pos.get("y", 0)),
            params=data.get("params", {}),
        )

    def to_json(self) -> dict:
        return {
            "id": self.id, "type": self.type, "domain": self.domain,
            "label": self.label, "position": {"x": self.x, "y": self.y},
            "params": self.params,
        }


@dataclass
class PipelineEdge:
    id: str
    source_node: str
    source_port: str = "output"
    target_node: str = ""
    target_port: str = "input"

    @classmethod
    def from_json(cls, data: dict) -> "PipelineEdge":
        return cls(
            id=data["id"],
            source_node=data.get("source") or data.get("source_node", ""),
            source_port=data.get("source_port", "output"),
            target_node=data.get("target") or data.get("target_node", ""),
            target_port=data.get("target_port", "input"),
        )

    def to_json(self) -> dict:
        return {
            "id": self.id, "source": self.source_node, "source_port": self.source_port,
            "target": self.target_node, "target_port": self.target_port,
        }


@dataclass
class PipelineParam:
    name: str
    type: str = "string"
    default: Any = None
    description: str = ""

    @classmethod
    def from_json(cls, data: dict) -> "PipelineParam":
        return cls(
            name=data["name"], type=data.get("type", "string"),
            default=data.get("default"), description=data.get("description", ""),
        )

    def to_json(self) -> dict:
        return {"name": self.name, "type": self.type, "default": self.default, "description": self.description}


@dataclass
class PipelineDefinition:
    id: str
    name: str
    description: str = ""
    nodes: list[PipelineNode] = field(default_factory=list)
    edges: list[PipelineEdge] = field(default_factory=list)
    parameters: list[PipelineParam] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

    @classmethod
    def from_json(cls, data: dict) -> "PipelineDefinition":
        nodes_raw = data.get("nodes", [])
        edges_raw = data.get("edges", [])
        params_raw = data.get("parameters", [])

        # Handle JSON strings
        if isinstance(nodes_raw, str):
            nodes_raw = json.loads(nodes_raw)
        if isinstance(edges_raw, str):
            edges_raw = json.loads(edges_raw)
        if isinstance(params_raw, str):
            params_raw = json.loads(params_raw)

        return cls(
            id=data["id"],
            name=data.get("name", "Untitled"),
            description=data.get("description", ""),
            nodes=[PipelineNode.from_json(n) for n in nodes_raw],
            edges=[PipelineEdge.from_json(e) for e in edges_raw],
            parameters=[PipelineParam.from_json(p) for p in params_raw],
        )

    def to_json(self) -> dict:
        return {
            "id": self.id, "name": self.name, "description": self.description,
            "nodes": [n.to_json() for n in self.nodes],
            "edges": [e.to_json() for e in self.edges],
            "parameters": [p.to_json() for p in self.parameters],
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }

    def to_summary(self) -> dict:
        return {
            "id": self.id, "name": self.name, "description": self.description,
            "node_count": len(self.nodes), "edge_count": len(self.edges),
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }


def resolve_variables(value: str, node_results: dict[str, dict], params: dict[str, Any]) -> Any:
    """Resolve {{nodeId.field}} and {{params.name}} references in a string."""
    if not isinstance(value, str):
        return value

    def _replace(m: re.Match) -> str:
        ref = m.group(1)
        if ref.startswith("params."):
            param_name = ref[7:]
            return str(params.get(param_name, m.group(0)))
        parts = ref.split(".", 1)
        if len(parts) == 2:
            node_id, field_name = parts
            result = node_results.get(node_id, {})
            return str(result.get(field_name, m.group(0)))
        return m.group(0)

    resolved = re.sub(r"\{\{(.+?)\}\}", _replace, value)

    # If the entire string was a single variable, try to preserve its type
    single_match = re.fullmatch(r"\{\{(.+?)\}\}", value)
    if single_match:
        ref = single_match.group(1)
        if ref.startswith("params."):
            return params.get(ref[7:], value)
        parts = ref.split(".", 1)
        if len(parts) == 2:
            node_id, field_name = parts
            result = node_results.get(node_id, {})
            if field_name in result:
                return result[field_name]

    return resolved
