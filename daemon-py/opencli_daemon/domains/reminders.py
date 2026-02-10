"""Reminders domain — Apple Reminders via AppleScript.

Ported from daemon/lib/domains/reminders/reminders_domain.dart.
"""

from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_osascript


class RemindersDomain(TaskDomain):
    id = "reminders"
    name = "Reminders"
    description = "Create, list, and complete reminders"
    icon = "checklist"
    color_hex = 0xFFFF9800

    task_types = ["reminders_add", "reminders_list", "reminders_complete"]

    display_configs = {
        "reminders_add": DomainDisplayConfig(
            card_type="reminders", title_template="Reminder Added",
            icon="add_task", color_hex=0xFFFF9800),
        "reminders_list": DomainDisplayConfig(
            card_type="reminders", title_template="Reminders",
            icon="checklist", color_hex=0xFFFF9800),
        "reminders_complete": DomainDisplayConfig(
            card_type="reminders", title_template="Reminder Completed",
            icon="task_alt", color_hex=0xFFFF9800),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        try:
            if task_type == "reminders_add":
                title = task_data.get("title", "Reminder")
                list_name = task_data.get("list", "Reminders")
                await run_osascript(
                    f'tell application "Reminders"\n'
                    f'  set targetList to list "{list_name}"\n'
                    f'  make new reminder at end of targetList '
                    f'with properties {{name:"{title}"}}\n'
                    f'end tell'
                )
                return {"success": True, "title": title, "list": list_name,
                        "domain": "reminders", "card_type": "reminders"}

            elif task_type == "reminders_list":
                result = await run_osascript(
                    'tell application "Reminders"\n'
                    '  set output to ""\n'
                    '  set rl to reminders of list "Reminders" whose completed is false\n'
                    '  repeat with r in rl\n'
                    '    set output to output & name of r & "\\n"\n'
                    '  end repeat\n'
                    '  return output\n'
                    'end tell',
                    timeout=30.0,
                )
                items = [line.strip() for line in result.split("\n") if line.strip()]
                return {"success": True, "reminders": items, "count": len(items),
                        "domain": "reminders", "card_type": "reminders"}

            elif task_type == "reminders_complete":
                title = task_data.get("title", "")
                await run_osascript(
                    f'tell application "Reminders"\n'
                    f'  set rl to reminders of list "Reminders" whose name contains "{title}"\n'
                    f'  repeat with r in rl\n'
                    f'    set completed of r to true\n'
                    f'  end repeat\n'
                    f'end tell'
                )
                return {"success": True, "completed": title,
                        "domain": "reminders", "card_type": "reminders"}

        except Exception as e:
            return {"success": False, "error": str(e), "domain": "reminders"}
        return {"success": False, "error": f"Unknown task: {task_type}", "domain": "reminders"}
