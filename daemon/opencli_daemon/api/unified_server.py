"""FastAPI application — Unified API server on port 9529.

Ported from daemon/lib/api/unified_api_server.dart.
"""

import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from opencli_daemon.database import connection as db

app = FastAPI(title="OpenCLI Daemon", version="0.2.0")

# CORS — allow all origins (mirrors Dart shelf CORS middleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Request counting middleware ──────────────────────────────────────────────

_request_count: int = 0


@app.middleware("http")
async def _count_requests(request: Request, call_next):
    global _request_count
    _request_count += 1
    return await call_next(request)


def get_request_count() -> int:
    return _request_count


@app.on_event("startup")
async def _startup() -> None:
    await db.get_db()


@app.on_event("shutdown")
async def _shutdown() -> None:
    await db.close_db()


# ── Health / Status ──────────────────────────────────────────────────────────


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.get("/api/v1/status")
async def status() -> dict:
    from datetime import datetime, timezone

    return {
        "status": "running",
        "version": "0.2.0-py",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ── Error handler ────────────────────────────────────────────────────────────


@app.exception_handler(Exception)
async def _global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={"error": str(exc)},
    )
