"""Files & Media domain — file operations and format conversion.

Ported from daemon/lib/domains/files_media/files_media_domain.dart.
"""

import os
from pathlib import Path
from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_command

_HOME = os.environ.get("HOME", ".")


def _expand_home(p: str) -> str:
    return p.replace("~", _HOME) if p.startswith("~") else p


def _resolve_dir(name: str) -> str:
    """Map friendly names to actual paths."""
    mapping = {
        "downloads": f"{_HOME}/Downloads",
        "desktop": f"{_HOME}/Desktop",
        "documents": f"{_HOME}/Documents",
        "pictures": f"{_HOME}/Pictures",
        "movies": f"{_HOME}/Movies",
        "music": f"{_HOME}/Music",
    }
    return mapping.get(name.lower(), _expand_home(name))


class FilesMediaDomain(TaskDomain):
    id = "files_media"
    name = "Files & Media"
    description = "Compress, convert, and organize files"
    icon = "folder"
    color_hex = 0xFF795548

    task_types = ["files_compress", "files_convert", "files_organize"]

    display_configs = {
        "files_compress": DomainDisplayConfig(
            card_type="files", title_template="Files Compressed",
            icon="archive", color_hex=0xFF795548),
        "files_convert": DomainDisplayConfig(
            card_type="files", title_template="Files Converted",
            icon="transform", color_hex=0xFF795548),
        "files_organize": DomainDisplayConfig(
            card_type="files", title_template="Files Organized",
            icon="folder_open", color_hex=0xFF795548),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        try:
            if task_type == "files_compress":
                return await self._compress(task_data)
            elif task_type == "files_convert":
                return await self._convert(task_data)
            elif task_type == "files_organize":
                return await self._organize(task_data)
        except Exception as e:
            return {"success": False, "error": str(e), "domain": "files_media"}
        return {"success": False, "error": f"Unknown task: {task_type}", "domain": "files_media"}

    async def _compress(self, data: dict) -> dict:
        path = _resolve_dir(data.get("path", "downloads"))
        archive_name = data.get("name", "archive.zip")
        archive_path = f"{path}/{archive_name}"

        stdout, stderr, rc = await run_command(
            ["bash", "-c", f'cd "{path}" && zip -r "{archive_path}" . -x ".*" -x "__MACOSX/*"'],
            timeout=120.0,
        )
        if rc != 0:
            return {"success": False, "error": stderr.strip(), "domain": "files_media"}
        return {"success": True, "archive": archive_path, "domain": "files_media", "card_type": "files"}

    async def _convert(self, data: dict) -> dict:
        path = _resolve_dir(data.get("path", "."))
        from_fmt = data.get("from_format", data.get("from", ""))
        to_fmt = data.get("to_format", data.get("to", ""))

        if not from_fmt or not to_fmt:
            return {"success": False, "error": "Missing from/to format", "domain": "files_media"}

        # Use sips for image conversion on macOS
        cmd = (
            f'for f in "{path}"/*.{from_fmt}; do '
            f'[ -f "$f" ] && sips -s format {to_fmt} "$f" '
            f'--out "${{f%.{from_fmt}}}.{to_fmt}"; done'
        )
        stdout, stderr, rc = await run_command(["bash", "-c", cmd], timeout=120.0)
        if rc != 0:
            return {"success": False, "error": stderr.strip(), "domain": "files_media"}
        return {"success": True, "from": from_fmt, "to": to_fmt, "path": path,
                "domain": "files_media", "card_type": "files"}

    async def _organize(self, data: dict) -> dict:
        path = _resolve_dir(data.get("path", "downloads"))

        script = f'''
cd "{path}" || exit 1
mkdir -p Images Documents Videos Music Archives Others
for f in *; do
  [ -f "$f" ] || continue
  ext=$(echo "${{f##*.}}" | tr '[:upper:]' '[:lower:]')
  case "$ext" in
    jpg|jpeg|png|gif|bmp|svg|webp|heic) mv "$f" Images/ 2>/dev/null ;;
    pdf|doc|docx|txt|rtf|xls|xlsx|csv|ppt|pptx) mv "$f" Documents/ 2>/dev/null ;;
    mp4|mov|avi|mkv|wmv|flv|webm) mv "$f" Videos/ 2>/dev/null ;;
    mp3|wav|flac|aac|ogg|m4a|wma) mv "$f" Music/ 2>/dev/null ;;
    zip|tar|gz|rar|7z|bz2|xz) mv "$f" Archives/ 2>/dev/null ;;
    *) mv "$f" Others/ 2>/dev/null ;;
  esac
done
# Remove empty directories
for d in Images Documents Videos Music Archives Others; do
  rmdir "$d" 2>/dev/null
done
echo "done"
'''
        stdout, stderr, rc = await run_command(["bash", "-c", script], timeout=60.0)
        if rc != 0:
            return {"success": False, "error": stderr.strip(), "domain": "files_media"}
        return {"success": True, "path": path, "domain": "files_media", "card_type": "files"}
