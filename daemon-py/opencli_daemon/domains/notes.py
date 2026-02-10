"""Notes domain — Apple Notes via AppleScript.

Ported from daemon/lib/domains/notes/notes_domain.dart.
"""

from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_osascript


class NotesDomain(TaskDomain):
    id = "notes"
    name = "Notes"
    description = "Create, search, and list Apple Notes"
    icon = "note"
    color_hex = 0xFFFFC107

    task_types = ["notes_create", "notes_search", "notes_list"]

    display_configs = {
        "notes_create": DomainDisplayConfig(
            card_type="notes", title_template="Note Created",
            icon="note_add", color_hex=0xFFFFC107),
        "notes_search": DomainDisplayConfig(
            card_type="notes", title_template="Notes Search",
            icon="search", color_hex=0xFFFFC107),
        "notes_list": DomainDisplayConfig(
            card_type="notes", title_template="Notes",
            icon="note", color_hex=0xFFFFC107),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        try:
            if task_type == "notes_create":
                title = task_data.get("title", "Untitled")
                body = task_data.get("body", "")
                await run_osascript(
                    f'tell application "Notes"\n'
                    f'  make new note at folder "Notes" '
                    f'with properties {{name:"{title}", body:"{body}"}}\n'
                    f'end tell',
                    timeout=30.0,
                )
                return {"success": True, "title": title, "domain": "notes", "card_type": "notes"}

            elif task_type == "notes_search":
                query = task_data.get("query", "")
                result = await run_osascript(
                    f'tell application "Notes"\n'
                    f'  set output to ""\n'
                    f'  set matchedNotes to every note of folder "Notes" '
                    f'whose name contains "{query}" or body contains "{query}"\n'
                    f'  set maxN to 10\n'
                    f'  set i to 0\n'
                    f'  repeat with n in matchedNotes\n'
                    f'    if i >= maxN then exit repeat\n'
                    f'    set output to output & name of n & "\\n"\n'
                    f'    set i to i + 1\n'
                    f'  end repeat\n'
                    f'  return output\n'
                    f'end tell',
                    timeout=30.0,
                )
                notes = [line.strip() for line in result.split("\n") if line.strip()]
                return {"success": True, "notes": notes, "count": len(notes),
                        "domain": "notes", "card_type": "notes"}

            elif task_type == "notes_list":
                result = await run_osascript(
                    'tell application "Notes"\n'
                    '  set output to ""\n'
                    '  set allNotes to every note of folder "Notes"\n'
                    '  set maxN to 10\n'
                    '  set i to 0\n'
                    '  repeat with n in allNotes\n'
                    '    if i >= maxN then exit repeat\n'
                    '    set output to output & name of n & "\\n"\n'
                    '    set i to i + 1\n'
                    '  end repeat\n'
                    '  return output\n'
                    'end tell',
                    timeout=30.0,
                )
                notes = [line.strip() for line in result.split("\n") if line.strip()]
                return {"success": True, "notes": notes, "count": len(notes),
                        "domain": "notes", "card_type": "notes"}

        except Exception as e:
            return {"success": False, "error": str(e), "domain": "notes"}
        return {"success": False, "error": f"Unknown task: {task_type}", "domain": "notes"}
