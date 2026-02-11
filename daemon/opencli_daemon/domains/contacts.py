"""Contacts domain — Apple Contacts via AppleScript.

Ported from daemon/lib/domains/contacts/contacts_domain.dart.
"""

from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_osascript


class ContactsDomain(TaskDomain):
    id = "contacts"
    name = "Contacts"
    description = "Search contacts and initiate calls"
    icon = "contacts"
    color_hex = 0xFF4CAF50

    task_types = ["contacts_find", "contacts_call"]

    display_configs = {
        "contacts_find": DomainDisplayConfig(
            card_type="contacts", title_template="Contacts",
            icon="person_search", color_hex=0xFF4CAF50),
        "contacts_call": DomainDisplayConfig(
            card_type="contacts", title_template="Calling",
            icon="call", color_hex=0xFF4CAF50),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        try:
            if task_type == "contacts_find":
                name = task_data.get("name", "")
                result = await run_osascript(
                    f'tell application "Contacts"\n'
                    f'  set output to ""\n'
                    f'  set matches to every person whose name contains "{name}"\n'
                    f'  repeat with p in matches\n'
                    f'    set pName to name of p\n'
                    f'    set pPhone to ""\n'
                    f'    set pEmail to ""\n'
                    f'    if (count of phones of p) > 0 then\n'
                    f'      set pPhone to value of first phone of p\n'
                    f'    end if\n'
                    f'    if (count of emails of p) > 0 then\n'
                    f'      set pEmail to value of first email of p\n'
                    f'    end if\n'
                    f'    set output to output & pName & "|||" & pPhone & "|||" & pEmail & "\\n"\n'
                    f'  end repeat\n'
                    f'  return output\n'
                    f'end tell',
                    timeout=30.0,
                )
                contacts = []
                for line in result.split("\n"):
                    parts = line.strip().split("|||")
                    if len(parts) >= 3 and parts[0]:
                        contacts.append({
                            "name": parts[0], "phone": parts[1], "email": parts[2],
                        })
                return {"success": True, "contacts": contacts, "count": len(contacts),
                        "domain": "contacts", "card_type": "contacts"}

            elif task_type == "contacts_call":
                name = task_data.get("name", "")
                result = await run_osascript(
                    f'tell application "Contacts"\n'
                    f'  set matches to every person whose name contains "{name}"\n'
                    f'  if (count of matches) > 0 then\n'
                    f'    set p to first item of matches\n'
                    f'    if (count of phones of p) > 0 then\n'
                    f'      set pPhone to value of first phone of p\n'
                    f'      tell application "FaceTime" to open location "tel://" & pPhone\n'
                    f'      return pPhone\n'
                    f'    end if\n'
                    f'  end if\n'
                    f'  return ""\n'
                    f'end tell',
                    timeout=30.0,
                )
                phone = result.strip()
                if phone:
                    return {"success": True, "name": name, "phone": phone,
                            "domain": "contacts", "card_type": "contacts"}
                return {"success": False, "error": f"No phone found for: {name}", "domain": "contacts"}

        except Exception as e:
            return {"success": False, "error": str(e), "domain": "contacts"}
        return {"success": False, "error": f"Unknown task: {task_type}", "domain": "contacts"}
