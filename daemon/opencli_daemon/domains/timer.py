"""Timer & Alarms domain.

Ported from daemon/lib/domains/timer/timer_domain.dart.
"""

import asyncio
import time
from datetime import datetime, timedelta
from typing import Any

from .base import TaskDomain, DomainDisplayConfig
from ..utils.subprocess_runner import run_osascript


class TimerDomain(TaskDomain):
    id = "timer"
    name = "Timer & Alarms"
    description = "Set timers, alarms, countdowns, and pomodoro sessions"
    icon = "timer"
    color_hex = 0xFF009688

    task_types = ["timer_set", "timer_cancel", "timer_status", "timer_pomodoro"]

    display_configs = {
        "timer_set": DomainDisplayConfig(
            card_type="timer",
            title_template="Timer: ${label}",
            subtitle_template="${minutes} minutes",
            icon="timer",
            color_hex=0xFF009688,
        ),
        "timer_status": DomainDisplayConfig(
            card_type="timer",
            title_template="Timer Status",
            icon="timer",
            color_hex=0xFF009688,
        ),
        "timer_pomodoro": DomainDisplayConfig(
            card_type="timer",
            title_template="Pomodoro",
            subtitle_template="25 min focus",
            icon="self_improvement",
            color_hex=0xFF009688,
        ),
    }

    def __init__(self) -> None:
        self._active_timers: dict[str, asyncio.Task] = {}
        self._timer_end_times: dict[str, datetime] = {}
        self._timer_labels: dict[str, str] = {}

    async def execute_task(
        self, task_type: str, task_data: dict[str, Any]
    ) -> dict[str, Any]:
        if task_type == "timer_set":
            return await self._set_timer(task_data)
        elif task_type == "timer_cancel":
            return self._cancel_timer()
        elif task_type == "timer_status":
            return self._timer_status()
        elif task_type == "timer_pomodoro":
            return await self._start_pomodoro(task_data)
        return {"success": False, "error": f"Unknown timer task: {task_type}"}

    async def _set_timer(self, data: dict) -> dict:
        minutes = int(data.get("minutes", 5))
        label = data.get("label", "Timer")
        timer_id = f"timer_{int(time.time() * 1000)}"

        self._cancel_all()

        end_time = datetime.now() + timedelta(minutes=minutes)
        self._timer_end_times[timer_id] = end_time
        self._timer_labels[timer_id] = label

        async def _notify_when_done():
            await asyncio.sleep(minutes * 60)
            try:
                await run_osascript(
                    f'display notification "{label} completed! ({minutes} min)" '
                    f'with title "OpenCLI Timer" sound name "Glass"'
                )
            except Exception:
                pass
            self._active_timers.pop(timer_id, None)
            self._timer_end_times.pop(timer_id, None)
            self._timer_labels.pop(timer_id, None)

        self._active_timers[timer_id] = asyncio.create_task(_notify_when_done())

        return {
            "success": True,
            "timer_id": timer_id,
            "minutes": minutes,
            "label": label,
            "ends_at": end_time.isoformat(),
            "domain": "timer",
            "card_type": "timer",
        }

    def _cancel_timer(self) -> dict:
        if not self._active_timers:
            return {"success": True, "message": "No active timers", "domain": "timer"}
        count = len(self._active_timers)
        self._cancel_all()
        return {"success": True, "message": f"Cancelled {count} timer(s)", "domain": "timer"}

    def _timer_status(self) -> dict:
        if not self._active_timers:
            return {
                "success": True,
                "active": False,
                "message": "No active timers",
                "domain": "timer",
            }
        timers = []
        for tid, end_time in self._timer_end_times.items():
            remaining = (end_time - datetime.now()).total_seconds()
            timers.append({
                "id": tid,
                "label": self._timer_labels.get(tid, "Timer"),
                "remaining_seconds": max(0, int(remaining)),
                "ends_at": end_time.isoformat(),
            })
        return {
            "success": True,
            "active": True,
            "timers": timers,
            "domain": "timer",
            "card_type": "timer",
        }

    async def _start_pomodoro(self, data: dict) -> dict:
        minutes = int(data.get("minutes", 25))
        return await self._set_timer({"minutes": minutes, "label": "Pomodoro Focus"})

    def _cancel_all(self) -> None:
        for task in self._active_timers.values():
            task.cancel()
        self._active_timers.clear()
        self._timer_end_times.clear()
        self._timer_labels.clear()
