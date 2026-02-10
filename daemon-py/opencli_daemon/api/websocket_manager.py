"""WebSocket manager for mobile client connections.

Ported from daemon/lib/mobile/mobile_connection_manager.dart.
Protocol: auth -> heartbeat -> submit_task -> task_update
"""

import asyncio
import json
import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from opencli_daemon.utils.auth import verify_token, DEFAULT_AUTH_SECRET

router = APIRouter()


@dataclass
class MobileClient:
    device_id: str
    websocket: WebSocket
    connected_at: datetime = field(default_factory=datetime.now)


class WebSocketManager:
    """Manages authenticated WebSocket connections from mobile/web clients."""

    def __init__(self, auth_secret: str = DEFAULT_AUTH_SECRET) -> None:
        self.auth_secret = auth_secret
        self._connections: dict[str, MobileClient] = {}
        self._cancelled_tasks: set[str] = set()

    @property
    def connected_clients(self) -> list[str]:
        return list(self._connections.keys())

    def is_task_cancelled(self, task_id: str) -> bool:
        return task_id in self._cancelled_tasks

    def clear_cancelled_task(self, task_id: str) -> None:
        self._cancelled_tasks.discard(task_id)

    async def send_to(self, device_id: str, data: dict) -> None:
        client = self._connections.get(device_id)
        if client:
            try:
                await client.websocket.send_json(data)
            except Exception:
                self._connections.pop(device_id, None)

    async def broadcast(self, data: dict) -> None:
        # FastAPI WebSocket clients
        dead: list[str] = []
        for did, client in self._connections.items():
            try:
                await client.websocket.send_json(data)
            except Exception:
                dead.append(did)
        for did in dead:
            self._connections.pop(did, None)

        # Standalone websockets clients (port 9876)
        if hasattr(self, '_ws_connections'):
            import json
            raw = json.dumps(data)
            dead2: list[str] = []
            for did, ws in self._ws_connections.items():
                try:
                    await ws.send(raw)
                except Exception:
                    dead2.append(did)
            for did in dead2:
                self._ws_connections.pop(did, None)

    async def handle_connection(self, ws: WebSocket) -> None:
        await ws.accept()
        device_id: str | None = None

        try:
            while True:
                raw = await ws.receive_text()
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    await ws.send_json({"type": "error", "message": "Invalid JSON"})
                    continue

                msg_type = msg.get("type", "")

                if msg_type == "auth":
                    device_id = await self._handle_auth(ws, msg)

                elif msg_type == "heartbeat":
                    await ws.send_json({"type": "heartbeat_ack"})

                elif msg_type == "submit_task":
                    if device_id is None:
                        await ws.send_json({"type": "error", "message": "Not authenticated"})
                        continue
                    await self._handle_task(ws, device_id, msg)

                elif msg_type == "cancel_task":
                    if device_id:
                        task_id = msg.get("task_id", "")
                        if task_id:
                            self._cancelled_tasks.add(task_id)
                            await ws.send_json({
                                "type": "task_cancelled",
                                "task_id": task_id,
                            })

                else:
                    await ws.send_json({"type": "error", "message": f"Unknown type: {msg_type}"})

        except WebSocketDisconnect:
            pass
        except Exception as e:
            print(f"[WS] Connection error: {e}")
        finally:
            if device_id:
                self._connections.pop(device_id, None)
                print(f"[WS] Client disconnected: {device_id}")

    async def _handle_auth(self, ws: WebSocket, msg: dict) -> str | None:
        device_id = msg.get("device_id")
        token = msg.get("token")
        timestamp = msg.get("timestamp")

        if not all([device_id, token, timestamp]):
            await ws.send_json({"type": "error", "message": "Missing authentication fields"})
            return None

        if not verify_token(device_id, int(timestamp), token, self.auth_secret):
            await ws.send_json({"type": "auth_failed", "message": "Invalid authentication token"})
            return None

        client = MobileClient(device_id=device_id, websocket=ws)
        self._connections[device_id] = client

        await ws.send_json({
            "type": "auth_success",
            "device_id": device_id,
            "server_time": int(time.time() * 1000),
        })
        print(f"[WS] Client authenticated: {device_id}")
        return device_id

    async def _handle_task(self, ws: WebSocket, device_id: str, msg: dict) -> None:
        task_type = msg.get("task_type", "")
        task_data = msg.get("task_data", {})
        task_id = msg.get("task_id", f"task_{int(time.time() * 1000)}")

        # Send running status
        await ws.send_json({
            "type": "task_update",
            "task_id": task_id,
            "task_type": task_type,
            "status": "running",
        })

        try:
            # Get registry from app state
            from opencli_daemon.api.unified_server import app
            registry = app.state.domain_registry

            # Progress callback for long-running tasks
            async def on_progress(progress_data: dict) -> None:
                await ws.send_json({
                    "type": "task_update",
                    "task_id": task_id,
                    "task_type": task_type,
                    "status": "running",
                    **progress_data,
                })

            result = await registry.execute_task_with_progress(
                task_type, task_data, on_progress=on_progress
            )

            await ws.send_json({
                "type": "task_update",
                "task_id": task_id,
                "task_type": task_type,
                "status": "completed",
                "result": result,
            })

        except Exception as e:
            await ws.send_json({
                "type": "task_update",
                "task_id": task_id,
                "task_type": task_type,
                "status": "failed",
                "result": {"success": False, "error": str(e)},
            })


# Singleton
ws_manager = WebSocketManager()


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await ws_manager.handle_connection(websocket)
