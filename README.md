<div align="center">

<img src="website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**An open-source agent for the models you run yourself**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](LICENSE)

**English** ·
[简体中文](./readme/README.zh-CN.md) ·
[繁體中文](./readme/README.zh-TW.md) ·
[日本語](./readme/README.ja.md) ·
[한국어](./readme/README.ko.md) ·
[Español](./readme/README.es.md) ·
[Português](./readme/README.pt-BR.md) ·
[Français](./readme/README.fr.md) ·
[Deutsch](./readme/README.de.md) ·
[Русский](./readme/README.ru.md)

[Download](https://opencli.ai/download.html) ·
[Documentation](https://docs.opencli.ai) ·
[Getting started](https://docs.opencli.ai/getting-started/install) ·
[Providers](https://docs.opencli.ai/getting-started/providers) ·
[Limits](https://docs.opencli.ai/reference/limits)

</div>

OpenCLI is an agent that runs on your own computer and works with any OpenAI-compatible model — one on the machine in front of you, one on your own server, or a hosted provider when you want one. It reads your files, runs your commands and edits your work, in a terminal and in a desktop app that share the same conversations.

**Nothing is built in.** No models, no accounts, no keys, and no opinion about where your inference comes from. Point it at an endpoint and its models appear on their own; what you type goes there and nowhere else.

## Download

| Platform | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

The app updates itself afterwards. These builds carry no Apple or Microsoft certificate, so the first launch needs one extra step — [what to do](https://docs.opencli.ai/getting-started/install).

**Command line, macOS and Linux:**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

Then point it at a model.

## What it does

- 🗂 **Works on files, not just code.** It reads a folder of invoices the same way it reads a repository — and most of the work people actually have is the first kind.

- 🏢 **Organised like an office.** A **department** is a directory with standing instructions. A **bot** is a chat inside one, with a job. Nine departments ship with sample data, so each can be tried before it is set up.

- ⏰ **Duties that come round on their own** — and stop to ask you when they reach something they should not decide alone. That threshold is written in words, in advance: *any single line over 10,000*.

- 🤝 **Bots hand work to each other,** with what they did and the files they produced. Capped at eight hops and three appearances each, so a cascade cannot run away.

- 🧰 **Six workflows ship as skills** and work in any directory: reviewing rows against their rules, reporting what changed over a week, triaging an inbox, comparing two drafts, turning a transcript into decisions and owners, and reading records for what is worth checking.

- 🔌 **Connectors are MCP servers** — GitHub, Postgres, Slack, Notion, a browser. Keys are kept away from the configuration file, which gets shared.

- 🚦 **A sandbox with a visible edge.** A run may write inside its own directory and nowhere else, and a run pointed somewhere unfamiliar is held until you allow that place by name.

- 🌍 **Ten languages,** and any other is one JSON file you can add without rebuilding anything.

- 💻 **Terminal, desktop and a local web UI** over the same gateway, so a conversation started in one continues in another.

## Works with

Not thirty integrations — one protocol. Anything answering `/v1/chat/completions` and `/v1/models` the way OpenAI does can be pointed at, and its models appear on their own. Every endpoint below was asked for its model list before being listed here.

**On your machine** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**On your server** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**Hosting open models** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**In China** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**Closed models, when you want one** — OpenAI · Anthropic · Mistral · xAI

Several give a free allowance, which is the cheapest way to try a model larger than your machine can hold. Endpoints, and which providers carry which model: [Providers](https://docs.opencli.ai/getting-started/providers).

> **Reachable is not the same as good at this.** Tool calling separates a model that can do this work from one that can only talk about it, and the model card never says.
> [Check yours](https://docs.opencli.ai/reference/checking-a-model) —
> one fixed task, five minutes. The table has one row because one model has been run, and **adding a row is the most useful contribution you can make.**

## What it cannot do

- **General open models reach for `grep` when they have a file tool.** A gap in the models; no interface closes it.
- **Token counts are estimated, never counted.** The tokenizer belongs to the model, and this runs models it has never seen.
- **Scheduled work runs only while OpenCLI is open.** A local agent, not a server.
- **A background run may write anything inside the directory it runs in.**
- **The desktop builds are not signed.** Your operating system is right to warn you.
- **Right-to-left languages are not laid out yet.**

[Limits](https://docs.opencli.ai/reference/limits) says why for each.

## Where this came from

A fork of [OpenAI's Codex CLI](https://github.com/openai/codex), Copyright 2025 OpenAI, Apache-2.0. **Not affiliated with OpenAI.**

Codex is built for OpenAI's models and this is built for everybody else's, which changes more than a name. Departments, bots, duties, background runs and the workflows are ours, as is a good deal of work on what breaks when the model is small — a compaction loop that summarised once a turn for eleven turns and threw away the thread each time, and a token estimate that read a page of Chinese as three quarters of its real cost.

[Apache-2.0](LICENSE) · [NOTICE](NOTICE) ·
[Contributing](https://docs.opencli.ai/reference/contributing)
