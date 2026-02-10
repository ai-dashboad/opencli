"""Daemon startup orchestrator.

Initializes DB, config, registers all API routers and domains,
then starts the uvicorn server + standalone WS server on port 9876
+ status server on port 9875.
"""

import asyncio
import json
import resource
import signal
import sys
import time

import uvicorn
import websockets

from opencli_daemon.database import connection as db
from opencli_daemon.api.unified_server import app

# Track daemon start time for uptime calculation
_start_time: float = time.time()


# ── Lazy router registration ─────────────────────────────────────────────────
# We import and attach routers here so that all modules can import `app`
# without circular dependency issues.


def _register_routers() -> None:
    """Import and mount all API routers onto the FastAPI app."""
    from opencli_daemon.api.config_api import router as config_router
    from opencli_daemon.api.storage_api import router as storage_router
    from opencli_daemon.api.pipeline_api import router as pipeline_router
    from opencli_daemon.api.episode_api import router as episode_router
    from opencli_daemon.api.lora_api import router as lora_router
    from opencli_daemon.api.local_models_api import router as local_models_router
    from opencli_daemon.api.websocket_manager import router as ws_router
    from opencli_daemon.api.execute_api import router as execute_router
    from opencli_daemon.api.files_api import router as files_router

    app.include_router(config_router)
    app.include_router(storage_router)
    app.include_router(pipeline_router)
    app.include_router(episode_router)
    app.include_router(lora_router)
    app.include_router(local_models_router)
    app.include_router(ws_router)
    app.include_router(execute_router)
    app.include_router(files_router)


def _register_domains() -> None:
    """Create the domain registry with all built-in domains."""
    from opencli_daemon.domains.registry import create_builtin_registry, set_registry

    registry = create_builtin_registry()
    set_registry(registry)
    # Store on app state so WS handler and APIs can access it
    app.state.domain_registry = registry
    print(
        f"[Daemon] Registered {len(registry.domains)} domains, "
        f"{len(registry.all_task_types)} task types"
    )


# ── Status server on port 9875 ───────────────────────────────────────────────


async def _run_status_server(port: int = 9875) -> None:
    """Lightweight HTTP server on port 9875 serving GET /status.

    Uses raw asyncio TCP server — no external dependency needed.
    """
    from opencli_daemon.api.websocket_manager import ws_manager
    from opencli_daemon.api.unified_server import get_request_count
    from datetime import datetime, timezone

    async def _handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            request_line = await asyncio.wait_for(reader.readline(), timeout=5)
            # Consume remaining headers
            while True:
                line = await asyncio.wait_for(reader.readline(), timeout=5)
                if line in (b"\r\n", b"\n", b""):
                    break

            method_path = request_line.decode("utf-8", errors="replace").strip()

            if "GET /status" in method_path or "GET / " in method_path:
                # Gather connected client IDs
                client_ids = list(ws_manager.connected_clients)
                if hasattr(ws_manager, "_ws_connections"):
                    for did in ws_manager._ws_connections:
                        if did not in client_ids:
                            client_ids.append(did)

                # Memory usage (macOS ru_maxrss is bytes, Linux is KB)
                rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
                if sys.platform == "darwin":
                    memory_mb = rss / (1024 * 1024)
                else:
                    memory_mb = rss / 1024

                body = json.dumps({
                    "daemon": {
                        "version": "0.2.0-py",
                        "uptime_seconds": int(time.time() - _start_time),
                        "memory_mb": round(memory_mb, 1),
                        "plugins_loaded": 0,
                        "total_requests": get_request_count(),
                    },
                    "mobile": {
                        "connected_clients": len(client_ids),
                        "client_ids": client_ids,
                    },
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                })
                status_line = "HTTP/1.1 200 OK"
            else:
                body = json.dumps({"error": "Not found"})
                status_line = "HTTP/1.1 404 Not Found"

            response = (
                f"{status_line}\r\n"
                "Content-Type: application/json\r\n"
                "Access-Control-Allow-Origin: *\r\n"
                "Access-Control-Allow-Methods: GET, OPTIONS\r\n"
                "Access-Control-Allow-Headers: *\r\n"
                f"Content-Length: {len(body.encode())}\r\n"
                "Connection: close\r\n"
                "\r\n"
                f"{body}"
            )
            writer.write(response.encode())
            await writer.drain()
        except Exception:
            pass
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except Exception:
                pass

    try:
        server = await asyncio.start_server(_handle_client, "0.0.0.0", port)
        print(f"[Daemon] Status server listening on http://0.0.0.0:{port}")
        async with server:
            await server.serve_forever()
    except OSError as e:
        print(f"[Daemon] Could not start status server on port {port}: {e}")


# ── Standalone WS server on port 9876 ────────────────────────────────────────


async def _run_mobile_ws_server(port: int = 9876) -> None:
    """Run a standalone websockets server on the mobile WS port.

    This reuses the same WebSocketManager from the FastAPI app so that
    clients connecting to either ws://host:9529/ws or ws://host:9876
    share the same connection pool and task execution pipeline.
    """
    from opencli_daemon.api.websocket_manager import ws_manager

    async def _handle(ws: websockets.ServerProtocol) -> None:
        """Adapt raw websockets connection to our WebSocketManager protocol."""
        from opencli_daemon.utils.auth import verify_token, DEFAULT_AUTH_SECRET

        device_id: str | None = None
        try:
            async for raw in ws:
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    await ws.send(json.dumps({"type": "error", "message": "Invalid JSON"}))
                    continue

                msg_type = msg.get("type", "")

                if msg_type == "auth":
                    did = msg.get("device_id")
                    token = msg.get("token")
                    timestamp = msg.get("timestamp")
                    if not all([did, token, timestamp]):
                        await ws.send(json.dumps({"type": "error", "message": "Missing auth fields"}))
                        continue
                    if not verify_token(did, int(timestamp), token, DEFAULT_AUTH_SECRET):
                        await ws.send(json.dumps({"type": "auth_failed", "message": "Invalid token"}))
                        continue
                    device_id = did
                    # Register a lightweight wrapper so broadcast works
                    ws_manager._ws_connections[device_id] = ws
                    await ws.send(json.dumps({
                        "type": "auth_success",
                        "device_id": device_id,
                        "server_time": int(time.time() * 1000),
                    }))
                    print(f"[WS:9876] Client authenticated: {device_id}")

                elif msg_type == "heartbeat":
                    await ws.send(json.dumps({"type": "heartbeat_ack"}))

                elif msg_type == "submit_task":
                    if not device_id:
                        await ws.send(json.dumps({"type": "error", "message": "Not authenticated"}))
                        continue
                    await _handle_task_standalone(ws, device_id, msg)

                elif msg_type == "chat":
                    if not device_id:
                        await ws.send(json.dumps({"type": "error", "message": "Not authenticated"}))
                        continue
                    message = msg.get("message", "")
                    await ws.send(json.dumps({"type": "chunk", "content": f"Echo: {message}"}))
                    await ws.send(json.dumps({"type": "done"}))

                elif msg_type == "cancel_task":
                    task_id = msg.get("task_id", "")
                    if task_id:
                        ws_manager._cancelled_tasks.add(task_id)
                        await ws.send(json.dumps({"type": "task_cancelled", "task_id": task_id}))

                else:
                    await ws.send(json.dumps({"type": "error", "message": f"Unknown: {msg_type}"}))

        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception as e:
            print(f"[WS:9876] Error: {e}")
        finally:
            if device_id:
                ws_manager._ws_connections.pop(device_id, None)
                print(f"[WS:9876] Client disconnected: {device_id}")

    async def _handle_task_standalone(ws, device_id: str, msg: dict) -> None:
        task_type = msg.get("task_type", "")
        task_data = msg.get("task_data", {})
        task_id = msg.get("task_id", f"task_{int(time.time() * 1000)}")

        # Broadcast task_submitted to all connected clients
        await ws_manager.broadcast({
            "type": "task_submitted",
            "task_type": task_type,
            "task_data": task_data,
            "device_id": device_id,
            "task_id": task_id,
        })

        await ws.send(json.dumps({
            "type": "task_update", "task_id": task_id,
            "task_type": task_type, "status": "running",
        }))

        try:
            registry = app.state.domain_registry

            async def on_progress(progress_data: dict) -> None:
                await ws.send(json.dumps({
                    "type": "task_update", "task_id": task_id,
                    "task_type": task_type, "status": "running",
                    **progress_data,
                }))

            result = await registry.execute_task_with_progress(
                task_type, task_data, on_progress=on_progress
            )
            status = "completed" if result.get("success", True) else "failed"
            await ws.send(json.dumps({
                "type": "task_update", "task_id": task_id,
                "task_type": task_type, "status": status,
                "result": result,
            }))
        except Exception as e:
            await ws.send(json.dumps({
                "type": "task_update", "task_id": task_id,
                "task_type": task_type, "status": "failed",
                "result": {"success": False, "error": str(e)},
            }))

    try:
        server = await websockets.serve(_handle, "0.0.0.0", port)
        print(f"[Daemon] Mobile WS server listening on ws://0.0.0.0:{port}")
        await asyncio.Future()  # run forever
    except OSError as e:
        print(f"[Daemon] Could not start WS on port {port}: {e}")


# ── Main entry ───────────────────────────────────────────────────────────────


async def start_daemon(port: int = 9529, ws_port: int = 9876, status_port: int = 9875) -> None:
    """Initialize everything and run the uvicorn server + WS server + status server."""
    global _start_time
    _start_time = time.time()

    print("=" * 50)
    print("  OpenCLI Daemon (Python/FastAPI)")
    print("=" * 50)

    # 1. Database
    await db.get_db()
    print("[Daemon] Database ready")

    # 2. Domains
    _register_domains()

    # 3. API routers
    _register_routers()
    print("[Daemon] API routers registered")

    # 4. Add _ws_connections dict for standalone WS server
    from opencli_daemon.api.websocket_manager import ws_manager
    if not hasattr(ws_manager, '_ws_connections'):
        ws_manager._ws_connections = {}

    # 5. Start servers
    config = uvicorn.Config(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info",
        ws_ping_interval=30,
        ws_ping_timeout=10,
    )
    server = uvicorn.Server(config)

    print(f"[Daemon] Starting on http://0.0.0.0:{port}")
    print(f"  - REST API: http://localhost:{port}/api/v1/")
    print(f"  - WebSocket: ws://localhost:{port}/ws")
    print(f"  - Mobile WS: ws://localhost:{ws_port}")
    print(f"  - Status: http://localhost:{status_port}/status")
    print(f"  - Health: http://localhost:{port}/health")

    # Run all three servers concurrently
    await asyncio.gather(
        server.serve(),
        _run_mobile_ws_server(ws_port),
        _run_status_server(status_port),
    )


def main() -> None:
    port = 9529
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
    asyncio.run(start_daemon(port))
