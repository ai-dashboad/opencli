#!/usr/bin/env python3
"""Write every README from one template and one set of translations.

Ten files, each linking to the other nine, is ninety links to keep in
agreement by hand — and a structure that drifts the moment somebody edits one
of them. So the shape is written once here and the languages supply only their
own sentences. A section added to the template appears in all ten; a language
that has not translated it yet shows the English, exactly as the interface
does.

Run after editing `readme/strings/*.json`:

    python3 scripts/readme-build.py
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STRINGS = ROOT / "readme" / "strings"

# code, name in itself, where the file goes
LANGUAGES = [
    ("en", "English", "README.md"),
    ("zh-CN", "简体中文", "readme/README.zh-CN.md"),
    ("zh-TW", "繁體中文", "readme/README.zh-TW.md"),
    ("ja", "日本語", "readme/README.ja.md"),
    ("ko", "한국어", "readme/README.ko.md"),
    ("es", "Español", "readme/README.es.md"),
    ("pt-BR", "Português", "readme/README.pt-BR.md"),
    ("fr", "Français", "readme/README.fr.md"),
    ("de", "Deutsch", "readme/README.de.md"),
    ("ru", "Русский", "readme/README.ru.md"),
]

REPO = "ai-dashboad/opencli"
RELEASE = f"https://github.com/{REPO}/releases/latest/download"
DOCS = "https://docs.opencli.ai"


def language_row(current: str) -> str:
    """The other nine, linked relative to where this file sits."""
    in_subdirectory = current.startswith("readme/")
    parts = []
    for _, label, path in LANGUAGES:
        if path == current:
            parts.append(f"**{label}**")
        elif in_subdirectory:
            href = "../README.md" if path == "README.md" else "./" + path.split("/", 1)[1]
            parts.append(f"[{label}]({href})")
        else:
            parts.append(f"[{label}](./{path})")
    return " ·\n".join(parts)


def render(code: str, path: str, text: dict[str, str], english: dict[str, str]) -> str:
    """The whole file. Anything untranslated falls back to English."""

    def s(key: str) -> str:
        return text.get(key) or english[key]

    up = "../" if path.startswith("readme/") else ""

    return f"""<div align="center">

<img src="{up}website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**{s("tagline")}**

[![CI](https://img.shields.io/github/actions/workflow/status/{REPO}/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/{REPO}/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/{REPO}?style=flat-square)](https://github.com/{REPO}/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/{REPO}/total?style=flat-square)](https://github.com/{REPO}/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)]({up}LICENSE)

{language_row(path)}

[{s("nav_download")}](https://opencli.ai/download.html) ·
[{s("nav_docs")}]({DOCS}) ·
[{s("nav_start")}]({DOCS}/getting-started/install) ·
[{s("nav_providers")}]({DOCS}/getting-started/providers) ·
[{s("nav_limits")}]({DOCS}/reference/limits)

</div>

{s("intro")}

{s("nothing_built_in")}

## {s("h_download")}

| {s("col_platform")} | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`]({RELEASE}/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`]({RELEASE}/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`]({RELEASE}/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`]({RELEASE}/OpenCLI-linux-x86_64.AppImage) |

{s("download_note")} — [{s("what_to_do")}]({DOCS}/getting-started/install).

**{s("command_line")}**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

{s("then_point")}

## {s("h_features")}

- 🗂 **{s("f_files_t")}** {s("f_files_b")}

- 🏢 **{s("f_office_t")}** {s("f_office_b")}

- ⏰ **{s("f_duty_t")}** {s("f_duty_b")}

- 🤝 **{s("f_handoff_t")}** {s("f_handoff_b")}

- 🧰 **{s("f_skills_t")}** {s("f_skills_b")}

- 🔌 **{s("f_connectors_t")}** {s("f_connectors_b")}

- 🚦 **{s("f_sandbox_t")}** {s("f_sandbox_b")}

- 🌍 **{s("f_languages_t")}** {s("f_languages_b")}

- 💻 **{s("f_surfaces_t")}** {s("f_surfaces_b")}

## {s("h_works_with")}

{s("protocol_not_integrations")}

**{s("g_local")}** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**{s("g_server")}** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**{s("g_hosted")}** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**{s("g_china")}** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**{s("g_closed")}** — OpenAI · Anthropic · Mistral · xAI

{s("free_allowance")} [{s("nav_providers")}]({DOCS}/getting-started/providers).

> **{s("reachable_t")}** {s("reachable_b")}
> [{s("check_yours")}]({DOCS}/reference/checking-a-model) —
> {s("check_note")}

## {s("h_cannot")}

- **{s("c_grep_t")}** {s("c_grep_b")}
- **{s("c_tokens_t")}** {s("c_tokens_b")}
- **{s("c_schedule_t")}** {s("c_schedule_b")}
- **{s("c_sandbox_t")}**
- **{s("c_signing_t")}** {s("c_signing_b")}
- **{s("c_rtl_t")}**

[{s("nav_limits")}]({DOCS}/reference/limits) {s("limits_note")}

## {s("h_origin")}

{s("origin_1")}

{s("origin_2")}

[Apache-2.0]({up}LICENSE) · [NOTICE]({up}NOTICE) ·
[{s("contributing")}]({DOCS}/reference/contributing)
"""


def main() -> int:
    english = json.loads((STRINGS / "en.json").read_text(encoding="utf-8"))
    for code, _, path in LANGUAGES:
        source = STRINGS / f"{code}.json"
        text = json.loads(source.read_text(encoding="utf-8")) if source.exists() else {}
        missing = [key for key in english if key not in text]
        (ROOT / path).write_text(render(code, path, text, english), encoding="utf-8")
        note = f", {len(missing)} left in English" if missing else ""
        print(f"  {code:<6} {path}{note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
