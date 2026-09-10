<div align="center">

<img src="../website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**Ein Open-Source-Agent für die Modelle, die Sie selbst betreiben**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](../LICENSE)

[English](../README.md) ·
[简体中文](./README.zh-CN.md) ·
[繁體中文](./README.zh-TW.md) ·
[日本語](./README.ja.md) ·
[한국어](./README.ko.md) ·
[Español](./README.es.md) ·
[Português](./README.pt-BR.md) ·
[Français](./README.fr.md) ·
**Deutsch** ·
[Русский](./README.ru.md)

[Herunterladen](https://opencli.ai/download.html) ·
[Dokumentation](https://docs.opencli.ai) ·
[Erste Schritte](https://docs.opencli.ai/getting-started/install) ·
[Anbieter](https://docs.opencli.ai/getting-started/providers) ·
[Grenzen](https://docs.opencli.ai/reference/limits)

</div>

OpenCLI ist ein Agent, der auf Ihrem eigenen Rechner läuft und mit jedem OpenAI-kompatiblen Modell arbeitet — einem auf der Maschine vor Ihnen, einem auf Ihrem eigenen Server, oder einem gehosteten Anbieter, wenn Ihnen danach ist. Er liest Ihre Dateien, führt Ihre Befehle aus und bearbeitet Ihre Arbeit, in einem Terminal und in einer Desktop-App, die dieselben Gespräche teilen.

**Nichts ist eingebaut.** Keine Modelle, keine Konten, keine Schlüssel und keine Meinung dazu, bei wem Sie Ihre Inferenz kaufen. Zeigen Sie auf einen Endpunkt, und seine Modelle erscheinen von selbst; was Sie tippen, geht dorthin und sonst nirgendwohin.

## Herunterladen

| Plattform | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

Danach aktualisiert sich die App selbst. Diese Builds tragen kein Zertifikat von Apple oder Microsoft, der erste Start braucht deshalb einen zusätzlichen Schritt — [was zu tun ist](https://docs.opencli.ai/getting-started/install).

**Kommandozeile, macOS und Linux:**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

Zeigen Sie ihn danach auf ein Modell.

## Was er tut

- 🗂 **Er arbeitet an Dateien, nicht nur an Code.** Er liest einen Ordner voller Rechnungen genauso wie ein Repository — und das meiste, was Leute tatsächlich zu tun haben, ist von der ersten Sorte.

- 🏢 **Aufgebaut wie ein Büro.** Eine **Abteilung** ist ein Verzeichnis mit dauerhaften Anweisungen. Ein **Bot** ist ein Gespräch darin, mit einer Aufgabe. Neun Abteilungen kommen mit Beispieldaten, jede lässt sich also ausprobieren, bevor sie eingerichtet wird.

- ⏰ **Dienste kommen von selbst an die Reihe** — und **halten an, um Sie zu fragen**, wenn sie an etwas geraten, das sie nicht allein entscheiden sollten. Diese Grenze wird vorher in Worten festgehalten: *jede einzelne Zeile über 10.000*.

- 🤝 **Bots reichen einander Arbeit weiter,** mitsamt dem, was sie getan haben, und den Dateien, die sie erzeugt haben. Gedeckelt auf acht Übergaben und drei Auftritte je Bot, damit eine Kette nicht davonläuft.

- 🧰 **Sechs Arbeitsabläufe kommen als Fertigkeiten mit** und funktionieren in jedem Verzeichnis: Zeilen gegen ihre Regeln prüfen, berichten was sich in einer Woche geändert hat, einen Posteingang sortieren, zwei Entwürfe vergleichen, ein Protokoll in Entscheidungen und Zuständige verwandeln, und Akten daraufhin lesen, was eine Prüfung wert ist.

- 🔌 **Konnektoren sind MCP-Server** — GitHub, Postgres, Slack, Notion, ein Browser. Schlüssel werden getrennt von der Konfigurationsdatei gehalten, die geteilt wird.

- 🚦 **Eine Sandbox mit sichtbarem Rand.** Ein Lauf darf in sein eigenes Verzeichnis schreiben und sonst nirgendwohin, und ein Lauf, der auf etwas Unbekanntes zeigt, wird zurückgehalten, bis Sie diesen Ort namentlich erlauben.

- 🌍 **Zehn Sprachen,** und jede weitere ist eine JSON-Datei, die Sie hinzufügen, ohne irgendetwas neu zu bauen.

- 💻 **Terminal, Desktop und eine lokale Weboberfläche** über dasselbe Gateway, sodass ein in einem begonnenes Gespräch im anderen weitergeht.

## Arbeitet mit

Keine dreißig Anbindungen — **ein Protokoll**. Alles, was `/v1/chat/completions` und `/v1/models` so beantwortet wie OpenAI, kann angesteuert werden, und seine Modelle erscheinen von selbst. Jeder Endpunkt unten wurde nach seiner Modellliste gefragt, bevor er hier aufgeführt wurde.

**Auf Ihrer Maschine** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**Auf Ihrem Server** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**Offene Modelle hostend** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**In China** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**Geschlossene Modelle, wenn Sie eines wollen** — OpenAI · Anthropic · Mistral · xAI

**Mehrere geben ein Freikontingent**, was der billigste Weg ist, ein Modell auszuprobieren, das größer ist als Ihr Rechner fassen kann. Endpunkte, und wer welches Modell führt: [Anbieter](https://docs.opencli.ai/getting-started/providers).

> **Erreichbar zu sein ist nicht dasselbe, wie darin gut zu sein.** Werkzeugaufrufe trennen ein Modell, das diese Arbeit tun kann, von einem, das nur darüber reden kann — und die Modellkarte sagt es nie.
> [Prüfen Sie Ihres](https://docs.opencli.ai/reference/checking-a-model) —
> eine feste Aufgabe, fünf Minuten. Die Tabelle hat eine Zeile, weil ein Modell gelaufen ist — **eine Zeile hinzuzufügen ist der nützlichste Beitrag, den Sie leisten können.**

## Was er nicht kann

- **Allgemeine offene Modelle greifen zu `grep`, auch wenn sie ein Dateiwerkzeug haben.** Eine Lücke in den Modellen; keine Oberfläche schließt sie.
- **Tokenzahlen werden geschätzt, nie gezählt.** Der Tokenizer gehört dem Modell, und dies führt Modelle aus, die es nie gesehen hat.
- **Geplante Arbeit läuft nur, solange OpenCLI offen ist.** Ein lokaler Agent, kein Server.
- **Ein Hintergrundlauf darf alles innerhalb des Verzeichnisses schreiben, in dem er läuft.**
- **Die Desktop-Builds sind nicht signiert.** Ihr Betriebssystem hat recht damit, Sie zu warnen.
- **Von rechts nach links geschriebene Sprachen sind noch nicht gesetzt.**

[Grenzen](https://docs.opencli.ai/reference/limits) nennt zu jedem Punkt den Grund.

## Woher das kommt

Ein Fork von [OpenAIs Codex CLI](https://github.com/openai/codex), Copyright 2025 OpenAI, Apache-2.0. **Nicht mit OpenAI verbunden.**

Codex ist für OpenAIs Modelle gebaut und dies für die aller anderen, was mehr ändert als einen Namen. Abteilungen, Bots, Dienste, Hintergrundläufe und die Arbeitsabläufe sind von hier, ebenso ein gutes Stück Arbeit daran, was kaputtgeht, wenn das Modell klein ist — eine Verdichtungsschleife, die elf Züge lang einmal pro Zug zusammenfasste und dabei jedes Mal den Faden wegwarf, und eine Tokenschätzung, die eine Seite Chinesisch als drei Viertel ihrer wirklichen Kosten las.

[Apache-2.0](../LICENSE) · [NOTICE](../NOTICE) ·
[Mitwirken](https://docs.opencli.ai/reference/contributing)
