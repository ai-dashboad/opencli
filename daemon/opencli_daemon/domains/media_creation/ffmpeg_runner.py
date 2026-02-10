"""Async FFmpeg subprocess runner.

Replaces Dart's Process.run for FFmpeg commands.
"""

import asyncio
import shutil
from typing import Sequence


_ffmpeg_path: str | None = None


def get_ffmpeg() -> str:
    """Find FFmpeg binary path."""
    global _ffmpeg_path
    if _ffmpeg_path is None:
        _ffmpeg_path = shutil.which("ffmpeg") or "ffmpeg"
    return _ffmpeg_path


def get_ffprobe() -> str:
    return shutil.which("ffprobe") or "ffprobe"


async def run_ffmpeg(args: Sequence[str], *, timeout: float = 300.0) -> tuple[str, str, int]:
    """Run an FFmpeg command. Returns (stdout, stderr, returncode)."""
    cmd = [get_ffmpeg(), *args]
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        raise TimeoutError(f"FFmpeg timed out after {timeout}s")
    return stdout.decode(), stderr.decode(), proc.returncode


async def run_ffprobe(args: Sequence[str], *, timeout: float = 30.0) -> tuple[str, str, int]:
    """Run an FFprobe command."""
    cmd = [get_ffprobe(), *args]
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        raise TimeoutError(f"FFprobe timed out after {timeout}s")
    return stdout.decode(), stderr.decode(), proc.returncode
