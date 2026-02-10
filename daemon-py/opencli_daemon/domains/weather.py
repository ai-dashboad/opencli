"""Weather domain — uses wttr.in API.

Ported from daemon/lib/domains/weather/weather_domain.dart.
"""

from typing import Any
from urllib.parse import quote

import httpx

from .base import TaskDomain, DomainDisplayConfig


class WeatherDomain(TaskDomain):
    id = "weather"
    name = "Weather"
    description = "Check current weather and forecast (uses wttr.in)"
    icon = "cloud"
    color_hex = 0xFF03A9F4

    task_types = ["weather_current", "weather_forecast"]

    display_configs = {
        "weather_current": DomainDisplayConfig(
            card_type="weather", title_template="Weather",
            icon="cloud", color_hex=0xFF03A9F4,
        ),
        "weather_forecast": DomainDisplayConfig(
            card_type="weather", title_template="Forecast",
            icon="wb_sunny", color_hex=0xFF03A9F4,
        ),
    }

    async def execute_task(
        self, task_type: str, task_data: dict[str, Any]
    ) -> dict[str, Any]:
        if task_type == "weather_current":
            return await self._current_weather(task_data)
        elif task_type == "weather_forecast":
            return await self._forecast(task_data)
        return {"success": False, "error": f"Unknown weather task: {task_type}"}

    async def _fetch_wttr(self, location: str) -> dict | None:
        url = f"https://wttr.in/{quote(location)}?format=j1"
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(url)
            if resp.status_code != 200:
                return None
            return resp.json()

    async def _current_weather(self, data: dict) -> dict:
        location = data.get("location", "")
        try:
            json_data = await self._fetch_wttr(location)
            if not json_data:
                return {"success": False, "error": "Failed to fetch weather data", "domain": "weather"}

            current = (json_data.get("current_condition") or [None])[0]
            if not current:
                return {"success": False, "error": "No weather data available", "domain": "weather"}

            area = (json_data.get("nearest_area") or [{}])[0]
            city = (area.get("areaName") or [{}])[0].get("value", location)
            country = (area.get("country") or [{}])[0].get("value", "")
            loc_str = f"{city}, {country}".strip().strip(",").strip()

            return {
                "success": True,
                "location": loc_str,
                "temperature_c": current.get("temp_C"),
                "temperature_f": current.get("temp_F"),
                "feels_like_c": current.get("FeelsLikeC"),
                "condition": (current.get("weatherDesc") or [{}])[0].get("value", ""),
                "humidity": current.get("humidity"),
                "wind_mph": current.get("windspeedMiles"),
                "wind_dir": current.get("winddir16Point"),
                "domain": "weather",
                "card_type": "weather",
            }
        except Exception as e:
            return {"success": False, "error": f"Weather error: {e}", "domain": "weather"}

    async def _forecast(self, data: dict) -> dict:
        location = data.get("location", "")
        try:
            json_data = await self._fetch_wttr(location)
            if not json_data:
                return {"success": False, "error": "Failed to fetch forecast", "domain": "weather"}

            weather = json_data.get("weather") or []
            if not weather:
                return {"success": False, "error": "No forecast data available", "domain": "weather"}

            area = (json_data.get("nearest_area") or [{}])[0]
            city = (area.get("areaName") or [{}])[0].get("value", location)

            days = []
            for day in weather:
                hourly = day.get("hourly") or []
                cond = (hourly[4].get("weatherDesc") or [{}])[0].get("value", "") if len(hourly) > 4 else ""
                days.append({
                    "date": day.get("date"),
                    "max_c": day.get("maxtempC"),
                    "min_c": day.get("mintempC"),
                    "max_f": day.get("maxtempF"),
                    "min_f": day.get("mintempF"),
                    "condition": cond,
                })

            return {
                "success": True, "location": city,
                "days": days, "domain": "weather", "card_type": "weather",
            }
        except Exception as e:
            return {"success": False, "error": f"Forecast error: {e}", "domain": "weather"}
