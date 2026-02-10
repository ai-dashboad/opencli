"""Calculator & Conversions domain.

Ported from daemon/lib/domains/calculator/calculator_domain.dart.
"""

import math
import re
from datetime import datetime, timedelta
from typing import Any

from .base import TaskDomain, DomainDisplayConfig


class CalculatorDomain(TaskDomain):
    id = "calculator"
    name = "Calculator & Conversions"
    description = "Math calculations, unit conversions, timezone, and date math"
    icon = "calculate"
    color_hex = 0xFF3F51B5

    task_types = [
        "calculator_eval",
        "calculator_convert",
        "calculator_timezone",
        "calculator_date_math",
    ]

    display_configs = {
        "calculator_eval": DomainDisplayConfig(
            card_type="calculator", title_template="Calculator",
            icon="calculate", color_hex=0xFF3F51B5,
        ),
        "calculator_convert": DomainDisplayConfig(
            card_type="calculator", title_template="Conversion",
            icon="swap_horiz", color_hex=0xFF3F51B5,
        ),
        "calculator_timezone": DomainDisplayConfig(
            card_type="calculator", title_template="Timezone",
            icon="public", color_hex=0xFF3F51B5,
        ),
        "calculator_date_math": DomainDisplayConfig(
            card_type="calculator", title_template="Date Calculation",
            icon="date_range", color_hex=0xFF3F51B5,
        ),
    }

    async def execute_task(
        self, task_type: str, task_data: dict[str, Any]
    ) -> dict[str, Any]:
        if task_type == "calculator_eval":
            return self._evaluate(task_data)
        elif task_type == "calculator_convert":
            return self._convert(task_data)
        elif task_type == "calculator_timezone":
            return self._timezone(task_data)
        elif task_type == "calculator_date_math":
            return self._date_math(task_data)
        return {"success": False, "error": f"Unknown calculator task: {task_type}"}

    # ── Evaluate ─────────────────────────────────────────────────────────

    def _evaluate(self, data: dict) -> dict:
        expr = data.get("expression", "")
        try:
            # Percentage: "15% of 234"
            m = re.match(r"([\d.]+)\s*%\s*(?:of)\s+([\d.]+)", expr)
            if m:
                pct, val = float(m.group(1)), float(m.group(2))
                result = (pct / 100) * val
                return self._eval_ok(expr, result)

            # sqrt
            m = re.match(r"sqrt\s*\(?([\d.]+)\)?", expr)
            if m:
                return self._eval_ok(expr, math.sqrt(float(m.group(1))))

            # power: "2^10"
            m = re.match(r"([\d.]+)\s*\^\s*([\d.]+)", expr)
            if m:
                return self._eval_ok(expr, float(m.group(1)) ** float(m.group(2)))

            # Simple arithmetic via safe eval
            result = self._simple_eval(expr)
            if result is not None:
                return self._eval_ok(expr, result)

            return {
                "success": False, "expression": expr,
                "error": "Could not evaluate expression", "domain": "calculator",
            }
        except Exception as e:
            return {
                "success": False, "expression": expr,
                "error": f"Calculation error: {e}", "domain": "calculator",
            }

    def _eval_ok(self, expr: str, result: float) -> dict:
        return {
            "success": True, "expression": expr,
            "result": _fmt(result), "domain": "calculator", "card_type": "calculator",
        }

    @staticmethod
    def _simple_eval(expr: str) -> float | None:
        """Safely evaluate basic arithmetic (+, -, *, /, parentheses)."""
        cleaned = re.sub(r"[^\d+\-*/.()\s]", "", expr).strip()
        if not cleaned:
            return None
        try:
            # Only allow safe chars (digits, operators, parens, dots, spaces)
            if re.fullmatch(r"[\d+\-*/.()\s]+", cleaned):
                return float(eval(cleaned))  # noqa: S307 – safe subset
        except Exception:
            pass
        return None

    # ── Convert ──────────────────────────────────────────────────────────

    _CONVERSIONS: dict[str, dict[str, float]] = {
        "miles": {"km": 1.60934, "meters": 1609.34, "feet": 5280},
        "km": {"miles": 0.621371, "meters": 1000, "feet": 3280.84},
        "meters": {"feet": 3.28084, "miles": 0.000621371, "km": 0.001, "inches": 39.3701},
        "feet": {"meters": 0.3048, "miles": 0.000189394, "km": 0.0003048, "inches": 12},
        "inches": {"cm": 2.54, "meters": 0.0254, "feet": 0.0833333},
        "cm": {"inches": 0.393701, "meters": 0.01, "feet": 0.0328084},
        "kg": {"lbs": 2.20462, "pounds": 2.20462, "oz": 35.274, "grams": 1000},
        "lbs": {"kg": 0.453592, "oz": 16, "grams": 453.592},
        "pounds": {"kg": 0.453592, "oz": 16, "grams": 453.592},
        "oz": {"grams": 28.3495, "kg": 0.0283495, "lbs": 0.0625},
        "grams": {"oz": 0.035274, "kg": 0.001, "lbs": 0.00220462},
        "liters": {"gallons": 0.264172, "cups": 4.22675, "ml": 1000},
        "gallons": {"liters": 3.78541, "cups": 16, "ml": 3785.41},
        "cups": {"ml": 236.588, "liters": 0.236588, "gallons": 0.0625},
    }

    _TEMP_UNITS = {"fahrenheit", "celsius", "kelvin", "f", "c", "k"}

    def _convert(self, data: dict) -> dict:
        value = float(data.get("value", 0))
        from_u = str(data.get("from", "")).lower()
        to_u = str(data.get("to", "")).lower()

        if from_u in self._TEMP_UNITS and to_u in self._TEMP_UNITS:
            result = self._convert_temp(value, from_u, to_u)
            if result is not None:
                return {
                    "success": True, "value": value, "from": from_u, "to": to_u,
                    "result": _fmt(result),
                    "display": f"{_fmt(value)} {from_u} = {_fmt(result)} {to_u}",
                    "domain": "calculator", "card_type": "calculator",
                }

        from_map = self._CONVERSIONS.get(from_u)
        if from_map and to_u in from_map:
            result = value * from_map[to_u]
            return {
                "success": True, "value": value, "from": from_u, "to": to_u,
                "result": _fmt(result),
                "display": f"{_fmt(value)} {from_u} = {_fmt(result)} {to_u}",
                "domain": "calculator", "card_type": "calculator",
            }

        return {"success": False, "error": f"Unknown conversion: {from_u} to {to_u}", "domain": "calculator"}

    @staticmethod
    def _convert_temp(value: float, from_u: str, to_u: str) -> float | None:
        f = "f" if from_u.startswith("f") else ("c" if from_u.startswith("c") else "k")
        t = "f" if to_u.startswith("f") else ("c" if to_u.startswith("c") else "k")
        if f == t:
            return value
        if f == "f" and t == "c": return (value - 32) * 5 / 9
        if f == "c" and t == "f": return value * 9 / 5 + 32
        if f == "c" and t == "k": return value + 273.15
        if f == "k" and t == "c": return value - 273.15
        if f == "f" and t == "k": return (value - 32) * 5 / 9 + 273.15
        if f == "k" and t == "f": return (value - 273.15) * 9 / 5 + 32
        return None

    # ── Timezone ─────────────────────────────────────────────────────────

    _TZ_OFFSETS: dict[str, int] = {
        "tokyo": 9, "japan": 9, "jst": 9,
        "london": 0, "uk": 0, "gmt": 0, "utc": 0,
        "new york": -5, "nyc": -5, "est": -5, "eastern": -5,
        "los angeles": -8, "la": -8, "pst": -8, "pacific": -8,
        "chicago": -6, "cst": -6, "central": -6,
        "denver": -7, "mst": -7, "mountain": -7,
        "paris": 1, "france": 1, "cet": 1,
        "berlin": 1, "germany": 1,
        "sydney": 11, "australia": 11, "aest": 11,
        "beijing": 8, "china": 8, "shanghai": 8,
        "mumbai": 5, "india": 5, "ist": 5, "delhi": 5,
        "dubai": 4, "uae": 4,
        "singapore": 8, "hong kong": 8,
        "seoul": 9, "korea": 9,
        "bangkok": 7, "thailand": 7,
        "moscow": 3, "russia": 3,
        "sao paulo": -3, "brazil": -3,
        "hawaii": -10, "hst": -10,
    }

    def _timezone(self, data: dict) -> dict:
        location = str(data.get("location", "")).lower().strip()
        offset = self._TZ_OFFSETS.get(location)
        if offset is None:
            return {"success": False, "error": f"Unknown timezone/city: {location}", "domain": "calculator"}

        from datetime import timezone as tz
        utc_now = datetime.now(tz.utc)
        local_time = utc_now + timedelta(hours=offset)
        formatted = local_time.strftime("%H:%M")
        date_str = local_time.strftime("%Y-%m-%d")
        sign = "+" if offset >= 0 else ""

        return {
            "success": True, "location": location,
            "time": formatted, "date": date_str,
            "offset": f"UTC{sign}{offset}",
            "display": f"It's {formatted} in {location.title()} ({date_str}, UTC{sign}{offset})",
            "domain": "calculator", "card_type": "calculator",
        }

    # ── Date math ────────────────────────────────────────────────────────

    def _date_math(self, data: dict) -> dict:
        op = data.get("operation", "")
        now = datetime.now()

        if op == "days_from_now":
            days = int(data.get("days", 0))
            target = now + timedelta(days=days)
            ds = target.strftime("%Y-%m-%d")
            return {
                "success": True, "days": days, "date": ds,
                "display": f"{days} days from now is {ds}",
                "domain": "calculator", "card_type": "calculator",
            }

        if op == "days_until":
            target_str = data.get("target", "")
            target_date = self._parse_date(target_str)
            if target_date is None:
                return {"success": False, "error": f"Could not parse date: {target_str}", "domain": "calculator"}
            days = (target_date - now).days
            return {
                "success": True, "target": target_str, "days": days,
                "display": f"{days} days until {target_str}",
                "domain": "calculator", "card_type": "calculator",
            }

        return {"success": False, "error": "Unknown date operation", "domain": "calculator"}

    @staticmethod
    def _parse_date(text: str) -> datetime | None:
        lower = text.lower().strip()
        now = datetime.now()
        year = now.year

        holidays = {
            "christmas": (12, 25), "new year": (1, 1), "new years": (1, 1),
            "valentines": (2, 14), "valentine": (2, 14),
            "halloween": (10, 31), "thanksgiving": (11, 28),
        }
        if lower in holidays:
            m, d = holidays[lower]
            y = year + 1 if lower in ("new year", "new years") else year
            dt = datetime(y, m, d)
            if dt < now:
                dt = datetime(y + 1, m, d)
            return dt

        months = {
            "january": 1, "february": 2, "march": 3, "april": 4,
            "may": 5, "june": 6, "july": 7, "august": 8,
            "september": 9, "october": 10, "november": 11, "december": 12,
        }
        for mname, mnum in months.items():
            pat = re.search(rf"{mname}\s+(\d+)", lower)
            if pat:
                day = int(pat.group(1))
                dt = datetime(year, mnum, day)
                if dt < now:
                    dt = datetime(year + 1, mnum, day)
                return dt
        return None


def _fmt(n: float) -> str:
    """Format number: drop .0 for integers."""
    if n == int(n):
        return str(int(n))
    return f"{n:.2f}"
