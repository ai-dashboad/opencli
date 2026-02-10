"""Calendar domain — Apple Calendar via AppleScript.

Ported from daemon/lib/domains/calendar/calendar_domain.dart.
"""

import re
from datetime import datetime, timedelta
from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_osascript


class CalendarDomain(TaskDomain):
    id = "calendar"
    name = "Calendar"
    description = "Create, list, and delete calendar events"
    icon = "calendar_today"
    color_hex = 0xFF2196F3

    task_types = ["calendar_add_event", "calendar_list_events", "calendar_delete_event"]

    display_configs = {
        "calendar_add_event": DomainDisplayConfig(
            card_type="calendar", title_template="Event Created",
            icon="event", color_hex=0xFF2196F3),
        "calendar_list_events": DomainDisplayConfig(
            card_type="calendar", title_template="Events",
            icon="calendar_today", color_hex=0xFF2196F3),
        "calendar_delete_event": DomainDisplayConfig(
            card_type="calendar", title_template="Event Deleted",
            icon="event_busy", color_hex=0xFF2196F3),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        try:
            if task_type == "calendar_add_event":
                return await self._add_event(task_data)
            elif task_type == "calendar_list_events":
                return await self._list_events(task_data)
            elif task_type == "calendar_delete_event":
                return await self._delete_event(task_data)
        except Exception as e:
            return {"success": False, "error": str(e), "domain": "calendar"}
        return {"success": False, "error": f"Unknown task: {task_type}", "domain": "calendar"}

    async def _add_event(self, data: dict) -> dict:
        title = data.get("title", "New Event")
        dt_raw = data.get("datetime_raw", "")
        calendar_name = data.get("calendar", "Home")

        # Parse time from datetime_raw
        now = datetime.now()
        hour, minute = 9, 0  # default 9am

        time_match = re.search(r"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?", dt_raw, re.I)
        if time_match:
            hour = int(time_match.group(1))
            minute = int(time_match.group(2) or 0)
            ampm = (time_match.group(3) or "").lower()
            if ampm == "pm" and hour < 12:
                hour += 12
            elif ampm == "am" and hour == 12:
                hour = 0

        # Parse day
        target_date = now
        lower = dt_raw.lower()
        if "tomorrow" in lower:
            target_date = now + timedelta(days=1)
        else:
            days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            for i, d in enumerate(days):
                if d in lower:
                    current_dow = now.weekday()
                    delta = (i - current_dow) % 7
                    if delta == 0:
                        delta = 7
                    target_date = now + timedelta(days=delta)
                    break

        start = target_date.replace(hour=hour, minute=minute, second=0, microsecond=0)
        end = start + timedelta(hours=1)

        start_str = start.strftime("%B %d, %Y at %I:%M:%S %p")
        end_str = end.strftime("%B %d, %Y at %I:%M:%S %p")

        await run_osascript(
            f'tell application "Calendar"\n'
            f'  tell calendar "{calendar_name}"\n'
            f'    make new event with properties '
            f'{{summary:"{title}", start date:date "{start_str}", end date:date "{end_str}"}}\n'
            f'  end tell\n'
            f'end tell',
            timeout=30.0,
        )
        return {
            "success": True, "title": title,
            "start": start.isoformat(), "end": end.isoformat(),
            "domain": "calendar", "card_type": "calendar",
        }

    async def _list_events(self, data: dict) -> dict:
        day = data.get("day", "today")
        now = datetime.now()
        if day == "tomorrow":
            target = now + timedelta(days=1)
        else:
            target = now

        date_str = target.strftime("%B %d, %Y")
        result = await run_osascript(
            f'tell application "Calendar"\n'
            f'  set startDate to date "{date_str} 12:00:00 AM"\n'
            f'  set endDate to date "{date_str} 11:59:59 PM"\n'
            f'  set output to ""\n'
            f'  repeat with c in calendars\n'
            f'    set evts to (every event of c whose start date >= startDate and start date <= endDate)\n'
            f'    repeat with e in evts\n'
            f'      set output to output & (time string of start date of e) & " - " & summary of e & "\\n"\n'
            f'    end repeat\n'
            f'  end repeat\n'
            f'  return output\n'
            f'end tell',
            timeout=30.0,
        )
        events = [line.strip() for line in result.split("\n") if line.strip()]
        return {
            "success": True, "events": events, "count": len(events),
            "date": date_str, "domain": "calendar", "card_type": "calendar",
        }

    async def _delete_event(self, data: dict) -> dict:
        title = data.get("title", "")
        await run_osascript(
            f'tell application "Calendar"\n'
            f'  repeat with c in calendars\n'
            f'    set evts to (every event of c whose summary contains "{title}")\n'
            f'    repeat with e in evts\n'
            f'      delete e\n'
            f'    end repeat\n'
            f'  end repeat\n'
            f'end tell',
            timeout=30.0,
        )
        return {"success": True, "deleted": title, "domain": "calendar", "card_type": "calendar"}
