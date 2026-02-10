"""Messages domain — Apple Messages via AppleScript.

Ported from daemon/lib/domains/messages/messages_domain.dart.
"""

from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_osascript


class MessagesDomain(TaskDomain):
    id = "messages"
    name = "Messages"
    description = "Send iMessages"
    icon = "message"
    color_hex = 0xFF4CAF50

    task_types = ["messages_send"]

    display_configs = {
        "messages_send": DomainDisplayConfig(
            card_type="messages", title_template="Message Sent",
            icon="send", color_hex=0xFF4CAF50),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        if task_type != "messages_send":
            return {"success": False, "error": f"Unknown task: {task_type}", "domain": "messages"}

        try:
            recipient = task_data.get("recipient", "")
            message = task_data.get("message", "")

            if not message:
                await run_osascript('tell application "Messages" to activate')
                return {"success": True, "action": "opened", "domain": "messages", "card_type": "messages"}

            # Look up phone from Contacts, then send via Messages
            phone = await run_osascript(
                f'tell application "Contacts"\n'
                f'  set matches to every person whose name contains "{recipient}"\n'
                f'  if (count of matches) > 0 then\n'
                f'    set p to first item of matches\n'
                f'    if (count of phones of p) > 0 then\n'
                f'      return value of first phone of p\n'
                f'    end if\n'
                f'  end if\n'
                f'  return "{recipient}"\n'
                f'end tell',
                timeout=15.0,
            )
            phone = phone.strip() or recipient

            await run_osascript(
                f'tell application "Messages"\n'
                f'  set targetService to first service whose service type = iMessage\n'
                f'  set targetBuddy to participant "{phone}" of targetService\n'
                f'  send "{message}" to targetBuddy\n'
                f'end tell',
                timeout=15.0,
            )
            return {"success": True, "recipient": recipient, "phone": phone,
                    "domain": "messages", "card_type": "messages"}

        except Exception as e:
            return {"success": False, "error": str(e), "domain": "messages"}
