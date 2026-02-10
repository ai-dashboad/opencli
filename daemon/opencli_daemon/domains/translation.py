"""Translation domain — uses Ollama for local translation.

Ported from daemon/lib/domains/translation/translation_domain.dart.
"""

from typing import Any

import httpx

from .base import TaskDomain, DomainDisplayConfig


class TranslationDomain(TaskDomain):
    id = "translation"
    name = "Translation"
    description = "Translate text between languages via Ollama"
    icon = "translate"
    color_hex = 0xFF673AB7

    task_types = ["translation_translate"]

    display_configs = {
        "translation_translate": DomainDisplayConfig(
            card_type="translation", title_template="Translation",
            icon="translate", color_hex=0xFF673AB7),
    }

    async def execute_task(self, task_type: str, task_data: dict[str, Any]) -> dict[str, Any]:
        if task_type != "translation_translate":
            return {"success": False, "error": f"Unknown task: {task_type}", "domain": "translation"}

        text = task_data.get("text", "")
        target_lang = task_data.get("target_language", task_data.get("language", "English"))

        if not text:
            return {"success": False, "error": "No text to translate", "domain": "translation"}

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(
                    "http://localhost:11434/api/generate",
                    json={
                        "model": "qwen2.5:latest",
                        "prompt": f"Translate the following text to {target_lang}. "
                                  f"Return ONLY the translation, nothing else:\n\n{text}",
                        "stream": False,
                    },
                )
                if resp.status_code != 200:
                    return {"success": False, "error": f"Ollama error: {resp.status_code}",
                            "domain": "translation"}

                data = resp.json()
                translation = data.get("response", "").strip()
                return {
                    "success": True,
                    "original": text,
                    "translation": translation,
                    "target_language": target_lang,
                    "domain": "translation",
                    "card_type": "translation",
                }
        except httpx.ConnectError:
            return {"success": False, "error": "Ollama not running (start with: ollama serve)",
                    "domain": "translation"}
        except Exception as e:
            return {"success": False, "error": f"Translation error: {e}", "domain": "translation"}
