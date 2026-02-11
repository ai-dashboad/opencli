"""File serving endpoint — serves files from ~/.opencli/ directory.

Allows the web UI to load generated images, videos, and audio files
produced by pipeline execution (keyframes, TTS audio, assembled videos).
"""

import mimetypes
from pathlib import Path

from fastapi import APIRouter
from fastapi.responses import FileResponse, JSONResponse

router = APIRouter(prefix="/api/v1", tags=["files"])

# Base directory for all served files
_OPENCLI_DIR = Path.home() / ".opencli"


@router.get("/files/{file_path:path}", response_model=None)
async def serve_file(file_path: str):
    """Serve a file from ~/.opencli/{file_path}.

    Security: resolved path must be within ~/.opencli/ to prevent traversal.
    """
    target = (_OPENCLI_DIR / file_path).resolve()

    # Path traversal check
    if not str(target).startswith(str(_OPENCLI_DIR.resolve())):
        return JSONResponse(
            status_code=403,
            content={"error": "Access denied: path outside allowed directory"},
        )

    if not target.is_file():
        return JSONResponse(
            status_code=404,
            content={"error": f"File not found: {file_path}"},
        )

    media_type, _ = mimetypes.guess_type(str(target))
    return FileResponse(
        path=str(target),
        media_type=media_type or "application/octet-stream",
        filename=target.name,
    )
