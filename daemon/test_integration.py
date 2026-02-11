#!/usr/bin/env python3
"""Integration tests for the Python FastAPI daemon.

Tests all REST endpoints and basic WebSocket auth.
"""

import asyncio
import hashlib
import json
import sys
import time

import httpx
import websockets

BASE = "http://localhost:9529"
WS_URL = "ws://localhost:9529/ws"
AUTH_SECRET = "opencli-dev-secret"

passed = 0
failed = 0
errors = []


def ok(name: str):
    global passed
    passed += 1
    print(f"  \033[32m✓\033[0m {name}")


def fail(name: str, reason: str):
    global failed
    failed += 1
    errors.append(f"{name}: {reason}")
    print(f"  \033[31m✗\033[0m {name} — {reason}")


async def test_rest():
    global passed, failed
    async with httpx.AsyncClient(base_url=BASE, timeout=10) as c:
        # ── Health / Status ──
        print("\n== Health & Status ==")
        r = await c.get("/health")
        if r.status_code == 200 and r.json().get("status") == "ok":
            ok("GET /health")
        else:
            fail("GET /health", f"{r.status_code} {r.text}")

        r = await c.get("/api/v1/status")
        d = r.json()
        if r.status_code == 200 and d.get("status") == "running":
            ok("GET /api/v1/status")
        else:
            fail("GET /api/v1/status", f"{r.status_code} {r.text}")

        # ── Config ──
        print("\n== Config ==")
        r = await c.get("/api/v1/config")
        if r.status_code == 200 and "config" in r.json():
            ok("GET /api/v1/config")
        else:
            fail("GET /api/v1/config", f"{r.status_code} {r.text}")

        # ── Storage: History ──
        print("\n== Storage: History ==")
        r = await c.get("/api/v1/history")
        if r.status_code == 200 and "history" in r.json():
            ok("GET /api/v1/history")
        else:
            fail("GET /api/v1/history", f"{r.status_code}")

        r = await c.post("/api/v1/history", json={
            "id": "test_h1", "mode": "txt2img", "prompt": "test prompt",
            "provider": "pollinations", "style": "cinematic"
        })
        if r.status_code == 200 and r.json().get("success"):
            ok("POST /api/v1/history")
        else:
            fail("POST /api/v1/history", f"{r.status_code} {r.text}")

        r = await c.delete("/api/v1/history/test_h1")
        if r.status_code == 200:
            ok("DELETE /api/v1/history/{id}")
        else:
            fail("DELETE /api/v1/history/{id}", f"{r.status_code}")

        # ── Storage: Assets ──
        print("\n== Storage: Assets ==")
        r = await c.get("/api/v1/assets")
        if r.status_code == 200 and "assets" in r.json():
            ok("GET /api/v1/assets")
        else:
            fail("GET /api/v1/assets", f"{r.status_code}")

        r = await c.post("/api/v1/assets", json={
            "id": "test_a1", "type": "image", "title": "Test Asset", "url": "/tmp/test.jpg"
        })
        if r.status_code == 200 and r.json().get("success"):
            ok("POST /api/v1/assets")
        else:
            fail("POST /api/v1/assets", f"{r.status_code} {r.text}")

        r = await c.delete("/api/v1/assets/test_a1")
        if r.status_code == 200:
            ok("DELETE /api/v1/assets/{id}")
        else:
            fail("DELETE /api/v1/assets/{id}", f"{r.status_code}")

        # ── Storage: Events ──
        print("\n== Storage: Events ==")
        r = await c.post("/api/v1/events", json={
            "type": "task", "source": "test", "content": "Testing",
            "task_type": "calculator_eval", "status": "completed"
        })
        if r.status_code == 200 and r.json().get("success"):
            ok("POST /api/v1/events")
        else:
            fail("POST /api/v1/events", f"{r.status_code} {r.text}")

        r = await c.get("/api/v1/events")
        if r.status_code == 200 and "events" in r.json():
            ok("GET /api/v1/events")
        else:
            fail("GET /api/v1/events", f"{r.status_code}")

        r = await c.get("/api/v1/events/stats")
        if r.status_code == 200 and "total" in r.json():
            ok("GET /api/v1/events/stats")
        else:
            fail("GET /api/v1/events/stats", f"{r.status_code}")

        # ── Storage: Chat Messages ──
        print("\n== Storage: Chat Messages ==")
        r = await c.get("/api/v1/chat/messages")
        if r.status_code == 200 and "messages" in r.json():
            ok("GET /api/v1/chat/messages")
        else:
            fail("GET /api/v1/chat/messages", f"{r.status_code}")

        # compat alias
        r = await c.get("/api/v1/chat-messages")
        if r.status_code == 200 and "messages" in r.json():
            ok("GET /api/v1/chat-messages (compat)")
        else:
            fail("GET /api/v1/chat-messages (compat)", f"{r.status_code}")

        r = await c.post("/api/v1/chat/messages", json={
            "id": "test_m1", "content": "Hello", "is_user": True
        })
        if r.status_code == 200 and r.json().get("success"):
            ok("POST /api/v1/chat/messages")
        else:
            fail("POST /api/v1/chat/messages", f"{r.status_code} {r.text}")

        r = await c.delete("/api/v1/chat/messages")
        if r.status_code == 200:
            ok("DELETE /api/v1/chat/messages")
        else:
            fail("DELETE /api/v1/chat/messages", f"{r.status_code}")

        # ── Pipelines CRUD ──
        print("\n== Pipelines ==")
        r = await c.get("/api/v1/pipelines")
        if r.status_code == 200 and "pipelines" in r.json():
            ok("GET /api/v1/pipelines")
        else:
            fail("GET /api/v1/pipelines", f"{r.status_code}")

        r = await c.post("/api/v1/pipelines", json={
            "id": "test_pipe", "name": "Test Pipeline",
            "nodes": [{"id": "n1", "type": "calculator_eval", "params": {"expression": "2+2"}, "position": {"x": 0, "y": 0}}],
            "edges": [], "parameters": []
        })
        if r.status_code == 200 and r.json().get("success"):
            ok("POST /api/v1/pipelines")
        else:
            fail("POST /api/v1/pipelines", f"{r.status_code} {r.text}")

        r = await c.get("/api/v1/pipelines/test_pipe")
        if r.status_code == 200 and r.json().get("pipeline"):
            ok("GET /api/v1/pipelines/{id}")
        else:
            fail("GET /api/v1/pipelines/{id}", f"{r.status_code}")

        r = await c.delete("/api/v1/pipelines/test_pipe")
        if r.status_code == 200:
            ok("DELETE /api/v1/pipelines/{id}")
        else:
            fail("DELETE /api/v1/pipelines/{id}", f"{r.status_code}")

        # ── Node Catalogs ──
        print("\n== Node Catalogs ==")
        r = await c.get("/api/v1/nodes/catalog")
        if r.status_code == 200 and "catalog" in r.json():
            catalog = r.json()["catalog"]
            ok(f"GET /api/v1/nodes/catalog ({len(catalog)} nodes)")
        else:
            fail("GET /api/v1/nodes/catalog", f"{r.status_code}")

        r = await c.get("/api/v1/nodes/video-catalog")
        if r.status_code == 200 and "nodes" in r.json():
            nodes = r.json()["nodes"]
            ok(f"GET /api/v1/nodes/video-catalog ({len(nodes)} nodes)")
        else:
            fail("GET /api/v1/nodes/video-catalog", f"{r.status_code}")

        # ── Episodes ──
        print("\n== Episodes ==")
        r = await c.get("/api/v1/episodes")
        if r.status_code == 200 and "episodes" in r.json():
            ok("GET /api/v1/episodes")
        else:
            fail("GET /api/v1/episodes", f"{r.status_code}")

        r = await c.post("/api/v1/episodes", json={
            "title": "Test Episode", "narrative": "A hero sets out on an adventure.",
            "scenes": [], "characters": []
        })
        if r.status_code == 200 and r.json().get("success"):
            ep_id = r.json().get("id")
            ok(f"POST /api/v1/episodes (id={ep_id})")
        else:
            fail("POST /api/v1/episodes", f"{r.status_code} {r.text}")
            ep_id = None

        if ep_id:
            r = await c.get(f"/api/v1/episodes/{ep_id}")
            if r.status_code == 200:
                ok(f"GET /api/v1/episodes/{ep_id}")
            else:
                fail(f"GET /api/v1/episodes/{{id}}", f"{r.status_code}")

            r = await c.delete(f"/api/v1/episodes/{ep_id}")
            if r.status_code == 200:
                ok("DELETE /api/v1/episodes/{id}")
            else:
                fail("DELETE /api/v1/episodes/{id}", f"{r.status_code}")

        # ── LoRAs ──
        print("\n== LoRAs & Recipes ==")
        r = await c.get("/api/v1/loras")
        if r.status_code == 200:
            ok("GET /api/v1/loras")
        else:
            fail("GET /api/v1/loras", f"{r.status_code}")

        r = await c.get("/api/v1/recipes")
        if r.status_code == 200:
            ok("GET /api/v1/recipes")
        else:
            fail("GET /api/v1/recipes", f"{r.status_code}")

        # ── Local Models ──
        print("\n== Local Models ==")
        r = await c.get("/api/v1/local-models")
        if r.status_code == 200 and "models" in r.json():
            models = r.json()["models"]
            ok(f"GET /api/v1/local-models ({len(models)} models)")
        else:
            fail("GET /api/v1/local-models", f"{r.status_code}")

        try:
            r = await c.get("/api/v1/local-models/environment", timeout=30)
            if r.status_code == 200:
                ok("GET /api/v1/local-models/environment")
            else:
                fail("GET /api/v1/local-models/environment", f"{r.status_code}")
        except httpx.ReadTimeout:
            fail("GET /api/v1/local-models/environment", "timeout (slow subprocess)")

        # ── Execute endpoint ──
        print("\n== Execute ==")
        r = await c.post("/api/v1/execute", json={
            "method": "calculator_eval",
            "params": [{"expression": "10+20"}],
        })
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            ok(f"POST /api/v1/execute calculator_eval → {d.get('result', {}).get('result')}")
        else:
            fail("POST /api/v1/execute calculator_eval", f"{r.status_code} {r.text}")

        r = await c.post("/api/v1/execute", json={
            "method": "system.info",
            "params": [],
        })
        d = r.json()
        if r.status_code == 200 and d.get("result", {}).get("hostname"):
            ok("POST /api/v1/execute system.info")
        else:
            fail("POST /api/v1/execute system.info", f"{r.status_code} {r.text}")

        r = await c.post("/api/v1/execute", json={
            "method": "domains.list",
            "params": [],
        })
        d = r.json()
        if r.status_code == 200 and d.get("result", {}).get("domains"):
            ok(f"POST /api/v1/execute domains.list ({len(d['result']['domains'])} domains)")
        else:
            fail("POST /api/v1/execute domains.list", f"{r.status_code} {r.text}")

        # ── Pipeline run-from-node ──
        print("\n== Pipeline run-from-node ==")
        # Create a 2-node pipeline: n1 → n2
        r = await c.post("/api/v1/pipelines", json={
            "id": "test_rfn", "name": "Run From Node Test",
            "nodes": [
                {"id": "n1", "type": "calculator_eval", "params": {"expression": "1+1"}, "position": {"x": 0, "y": 0}},
                {"id": "n2", "type": "calculator_eval", "params": {"expression": "3+4"}, "position": {"x": 200, "y": 0}},
            ],
            "edges": [{"id": "e1", "source": "n1", "target": "n2", "source_port": "output", "target_port": "input"}],
            "parameters": [],
        })
        if r.status_code == 200:
            # Run from n2, skipping n1
            r = await c.post("/api/v1/pipelines/test_rfn/run-from/n2", json={
                "previous_results": {"n1": {"success": True, "result": 2}},
            })
            d = r.json()
            if d.get("success") and d.get("node_statuses", {}).get("n2") == "completed":
                ok("POST /api/v1/pipelines/{id}/run-from/{nodeId}")
            else:
                fail("POST /api/v1/pipelines/{id}/run-from/{nodeId}", f"{d}")

            await c.delete("/api/v1/pipelines/test_rfn")
        else:
            fail("POST /api/v1/pipelines (run-from-node setup)", f"{r.status_code}")

        # ── Episodes from-script ──
        print("\n== Episodes from-script ==")
        r = await c.post("/api/v1/episodes/from-script", json={
            "script": {
                "title": "Test Script Episode",
                "narrative": "A warrior defeats the dragon.",
                "scenes": [{"description": "Battle scene", "dialogue": []}],
                "characters": [{"name": "Hero", "visual_description": "tall warrior"}],
            }
        })
        d = r.json()
        if r.status_code == 200 and d.get("success") and d.get("id"):
            from_script_id = d["id"]
            ok(f"POST /api/v1/episodes/from-script (id={from_script_id})")
            # Verify it was saved
            r = await c.get(f"/api/v1/episodes/{from_script_id}")
            if r.status_code == 200 and r.json().get("episode", {}).get("title") == "Test Script Episode":
                ok("GET /api/v1/episodes/{id} (from-script)")
            else:
                fail("GET /api/v1/episodes/{id} (from-script)", f"{r.status_code}")
            await c.delete(f"/api/v1/episodes/{from_script_id}")
        else:
            fail("POST /api/v1/episodes/from-script", f"{r.status_code} {r.text}")


async def test_websocket():
    print("\n== WebSocket Auth ==")
    device_id = "test_device_py"
    ts = str(int(time.time() * 1000))
    raw = f"{device_id}:{ts}:{AUTH_SECRET}"
    token = hashlib.sha256(raw.encode()).hexdigest()

    try:
        async with websockets.connect(WS_URL, open_timeout=5) as ws:
            # Send auth
            await ws.send(json.dumps({
                "type": "auth",
                "device_id": device_id,
                "timestamp": ts,
                "token": token,
                "device_name": "Integration Test",
                "platform": "test"
            }))
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            if resp.get("type") == "auth_success":
                ok("WS auth_success")
            else:
                fail("WS auth", f"Expected auth_success, got {resp.get('type')}: {resp}")

            # Test heartbeat
            await ws.send(json.dumps({"type": "heartbeat"}))
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            if resp.get("type") == "heartbeat_ack":
                ok("WS heartbeat_ack")
            else:
                fail("WS heartbeat", f"Expected heartbeat_ack, got {resp}")

            # Helper to get final task_update (skip running statuses)
            async def recv_task_result(timeout_s=15):
                deadline = time.time() + timeout_s
                while True:
                    remaining = deadline - time.time()
                    if remaining <= 0:
                        return None
                    resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=remaining))
                    if resp.get("type") == "task_update" and resp.get("status") in ("completed", "failed"):
                        return resp
                    # skip running / progress updates

            # Test calculator task
            await ws.send(json.dumps({
                "type": "submit_task",
                "request_id": "req_calc_1",
                "task_type": "calculator_eval",
                "task_data": {"expression": "2+3*4"}
            }))
            resp = await recv_task_result()
            if resp and resp.get("status") == "completed":
                result = resp.get("result", {})
                val = result.get("result", {}).get("result") if isinstance(result.get("result"), dict) else result.get("result")
                ok(f"WS calculator_eval → {val}")
            else:
                fail("WS calculator_eval", f"Got: {resp}")

            # Test weather task
            await ws.send(json.dumps({
                "type": "submit_task",
                "request_id": "req_weather_1",
                "task_type": "weather_current",
                "task_data": {"city": "Tokyo"}
            }))
            resp = await recv_task_result()
            if resp and resp.get("status") == "completed":
                ok("WS weather_current Tokyo")
            else:
                fail("WS weather_current", f"Got: {resp}")

            # Test timer (just check it returns something — timer fires async)
            await ws.send(json.dumps({
                "type": "submit_task",
                "request_id": "req_timer_1",
                "task_type": "timer_set",
                "task_data": {"duration": "1s", "label": "test"}
            }))
            resp = await recv_task_result(timeout_s=10)
            if resp:
                ok(f"WS timer_set → {resp.get('status')}")
            else:
                fail("WS timer_set", "No final response")

    except Exception as e:
        fail("WS connection", str(e))


async def test_ws_chat():
    print("\n== WebSocket Chat ==")
    device_id = "test_chat_py"
    ts = str(int(time.time() * 1000))
    raw = f"{device_id}:{ts}:{AUTH_SECRET}"
    token = hashlib.sha256(raw.encode()).hexdigest()

    try:
        async with websockets.connect(WS_URL, open_timeout=5) as ws:
            # Auth first
            await ws.send(json.dumps({
                "type": "auth", "device_id": device_id,
                "timestamp": ts, "token": token,
            }))
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            if resp.get("type") != "auth_success":
                fail("WS chat auth", f"Expected auth_success, got {resp}")
                return

            # Send chat
            await ws.send(json.dumps({
                "type": "chat", "message": "Hello world",
            }))

            # Expect chunk + done
            chunk = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            done = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))

            if chunk.get("type") == "chunk" and "Echo: Hello world" in chunk.get("content", ""):
                ok("WS chat → chunk received")
            else:
                fail("WS chat chunk", f"Got: {chunk}")

            if done.get("type") == "done":
                ok("WS chat → done received")
            else:
                fail("WS chat done", f"Got: {done}")

    except Exception as e:
        fail("WS chat", str(e))


async def test_ws_task_submitted():
    print("\n== WebSocket task_submitted ==")
    device_id = "test_submitted_py"
    ts = str(int(time.time() * 1000))
    raw = f"{device_id}:{ts}:{AUTH_SECRET}"
    token = hashlib.sha256(raw.encode()).hexdigest()

    try:
        async with websockets.connect(WS_URL, open_timeout=5) as ws:
            await ws.send(json.dumps({
                "type": "auth", "device_id": device_id,
                "timestamp": ts, "token": token,
            }))
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            if resp.get("type") != "auth_success":
                fail("WS task_submitted auth", f"Expected auth_success, got {resp}")
                return

            # Submit a task
            await ws.send(json.dumps({
                "type": "submit_task",
                "task_type": "calculator_eval",
                "task_data": {"expression": "1+1"},
                "task_id": "test_sub_1",
            }))

            # Collect all messages until we get task_update completed/failed
            got_submitted = False
            deadline = time.time() + 15
            while time.time() < deadline:
                remaining = deadline - time.time()
                resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=remaining))
                if resp.get("type") == "task_submitted":
                    got_submitted = True
                elif resp.get("type") == "task_update" and resp.get("status") in ("completed", "failed"):
                    break

            if got_submitted:
                ok("WS task_submitted broadcast received")
            else:
                fail("WS task_submitted", "Never received task_submitted message")

    except Exception as e:
        fail("WS task_submitted", str(e))


async def test_status_server():
    print("\n== Status Server (port 9875) ==")
    try:
        async with httpx.AsyncClient(timeout=5) as c:
            r = await c.get("http://localhost:9875/status")
            d = r.json()
            if r.status_code == 200 and "daemon" in d and "mobile" in d:
                daemon_info = d["daemon"]
                ok(f"GET :9875/status (uptime={daemon_info.get('uptime_seconds')}s, "
                   f"mem={daemon_info.get('memory_mb')}MB, "
                   f"reqs={daemon_info.get('total_requests')})")
            else:
                fail("GET :9875/status", f"{r.status_code} {r.text}")
    except Exception as e:
        fail("GET :9875/status", str(e))


async def test_ws_bad_auth():
    print("\n== WebSocket Bad Auth ==")
    try:
        async with websockets.connect(WS_URL, open_timeout=5) as ws:
            await ws.send(json.dumps({
                "type": "auth",
                "device_id": "bad_device",
                "timestamp": str(int(time.time() * 1000)),
                "token": "wrong_token",
            }))
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            if resp.get("type") == "auth_failed":
                ok("WS rejects bad token")
            else:
                fail("WS bad auth", f"Expected auth_failed, got {resp.get('type')}")
    except Exception as e:
        fail("WS bad auth", str(e))


async def main():
    print("=" * 60)
    print("  OpenCLI Python Daemon — Integration Tests")
    print("=" * 60)

    await test_rest()
    await test_status_server()
    await test_websocket()
    await test_ws_chat()
    await test_ws_task_submitted()
    await test_ws_bad_auth()

    print("\n" + "=" * 60)
    print(f"  Results: {passed} passed, {failed} failed")
    print("=" * 60)

    if errors:
        print("\nFailures:")
        for e in errors:
            print(f"  - {e}")

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    asyncio.run(main())
