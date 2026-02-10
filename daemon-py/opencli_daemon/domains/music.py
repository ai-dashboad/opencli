"""Music domain — Apple Music control via AppleScript.

Ported from daemon/lib/domains/music/music_domain.dart.
"""

from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_osascript


class MusicDomain(TaskDomain):
    id = "music"
    name = "Music"
    description = "Control Apple Music — play, pause, skip, now playing"
    icon = "music_note"
    color_hex = 0xFFE91E63

    task_types = [
        "music_play", "music_pause", "music_next",
        "music_previous", "music_now_playing", "music_playlist",
    ]

    display_configs = {
        "music_play": DomainDisplayConfig(
            card_type="music", title_template="Music: Play",
            icon="play_arrow", color_hex=0xFFE91E63),
        "music_pause": DomainDisplayConfig(
            card_type="music", title_template="Music: Paused",
            icon="pause", color_hex=0xFFE91E63),
        "music_now_playing": DomainDisplayConfig(
            card_type="music", title_template="Now Playing",
            icon="music_note", color_hex=0xFFE91E63),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        try:
            if task_type == "music_play":
                query = task_data.get("query", "")
                if query:
                    await run_osascript(
                        f'tell application "Music" to play (first track whose name contains "{query}")'
                    )
                else:
                    await run_osascript('tell application "Music" to play')
                return {"success": True, "action": "play", "domain": "music", "card_type": "music"}

            elif task_type == "music_pause":
                await run_osascript('tell application "Music" to pause')
                return {"success": True, "action": "pause", "domain": "music", "card_type": "music"}

            elif task_type == "music_next":
                await run_osascript('tell application "Music" to next track')
                return {"success": True, "action": "next", "domain": "music", "card_type": "music"}

            elif task_type == "music_previous":
                await run_osascript('tell application "Music" to previous track')
                return {"success": True, "action": "previous", "domain": "music", "card_type": "music"}

            elif task_type == "music_now_playing":
                result = await run_osascript(
                    'tell application "Music"\n'
                    '  set t to name of current track\n'
                    '  set a to artist of current track\n'
                    '  set al to album of current track\n'
                    '  return t & "|||" & a & "|||" & al\n'
                    'end tell'
                )
                parts = result.split("|||")
                return {
                    "success": True,
                    "track": parts[0] if parts else "",
                    "artist": parts[1] if len(parts) > 1 else "",
                    "album": parts[2] if len(parts) > 2 else "",
                    "domain": "music", "card_type": "music",
                }

            elif task_type == "music_playlist":
                playlist = task_data.get("playlist", "")
                if playlist:
                    await run_osascript(f'tell application "Music" to play playlist "{playlist}"')
                    return {"success": True, "playlist": playlist, "domain": "music", "card_type": "music"}
                return {"success": False, "error": "No playlist specified", "domain": "music"}

        except Exception as e:
            return {"success": False, "error": str(e), "domain": "music"}
        return {"success": False, "error": f"Unknown task: {task_type}", "domain": "music"}
