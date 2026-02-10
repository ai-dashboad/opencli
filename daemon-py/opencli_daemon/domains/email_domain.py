"""Email domain — Apple Mail via AppleScript.

Ported from daemon/lib/domains/email/email_domain.dart.
"""

from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_osascript


class EmailDomain(TaskDomain):
    id = "email"
    name = "Email"
    description = "Compose emails and check inbox via Apple Mail"
    icon = "email"
    color_hex = 0xFFF44336

    task_types = ["email_compose", "email_check"]

    display_configs = {
        "email_compose": DomainDisplayConfig(
            card_type="email", title_template="Email Draft",
            icon="drafts", color_hex=0xFFF44336),
        "email_check": DomainDisplayConfig(
            card_type="email", title_template="Inbox",
            icon="inbox", color_hex=0xFFF44336),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        try:
            if task_type == "email_compose":
                to = task_data.get("to", "")
                subject = task_data.get("subject", "")
                body = task_data.get("body", "")
                await run_osascript(
                    f'tell application "Mail"\n'
                    f'  set msg to make new outgoing message with properties '
                    f'{{subject:"{subject}", content:"{body}"}}\n'
                    f'  tell msg\n'
                    f'    make new to recipient at end of to recipients '
                    f'with properties {{address:"{to}"}}\n'
                    f'  end tell\n'
                    f'  activate\n'
                    f'end tell',
                    timeout=30.0,
                )
                return {"success": True, "to": to, "subject": subject,
                        "domain": "email", "card_type": "email"}

            elif task_type == "email_check":
                result = await run_osascript(
                    'tell application "Mail"\n'
                    '  check for new mail\n'
                    '  set unreadCount to unread count of inbox\n'
                    '  return unreadCount as text\n'
                    'end tell',
                    timeout=30.0,
                )
                count = int(result.strip()) if result.strip().isdigit() else 0
                return {"success": True, "unread": count,
                        "domain": "email", "card_type": "email"}

        except Exception as e:
            return {"success": False, "error": str(e), "domain": "email"}
        return {"success": False, "error": f"Unknown task: {task_type}", "domain": "email"}
