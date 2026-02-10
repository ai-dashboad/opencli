"""Async subprocess helper for AppleScript and FFmpeg calls."""

import asyncio
from typing import Sequence


async def run_osascript(script: str, timeout: float = 30.0) -> str:
    """Run an AppleScript and return stdout."""
    proc = await asyncio.create_subprocess_exec(
        "osascript", "-e", script,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(
            proc.communicate(), timeout=timeout
        )
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        raise TimeoutError(f"osascript timed out after {timeout}s")

    if proc.returncode != 0:
        err = stderr.decode().strip()
        raise RuntimeError(f"osascript error (code {proc.returncode}): {err}")
    return stdout.decode().strip()


async def run_command(
    args: Sequence[str],
    *,
    timeout: float = 120.0,
    cwd: str | None = None,
) -> tuple[str, str, int]:
    """Run a command and return (stdout, stderr, returncode)."""
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=cwd,
    )
    try:
        stdout, stderr = await asyncio.wait_for(
            proc.communicate(), timeout=timeout
        )
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        raise TimeoutError(f"Command timed out after {timeout}s: {args[0]}")

    return stdout.decode(), stderr.decode(), proc.returncode
