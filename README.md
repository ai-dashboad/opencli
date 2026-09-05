# OpenCLI

**[中文](./README.zh-CN.md)** · English

Every frontier model has an agent of its own. Claude has Claude Code, OpenAI
has Codex, Gemini has its CLI.

The models you can actually run — Qwen, DeepSeek, GLM, Llama, Mistral — have
none.

**OpenCLI is theirs.** A terminal agent and a desktop app that point at
whatever OpenAI-compatible endpoint you like: a model on the machine in front
of you, your own gateway, or a hosted provider when you want one. It ships with
no models, no accounts and no keys.

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

Or [download the desktop app](https://opencli.ai/download.html) for macOS,
Windows or Linux.

---

## It is not only for code

The agent reads files, runs commands and edits things. That is as true of a
folder of invoices as it is of a repository, and most of the work people
actually have is the first kind.

So the desktop app is organised the way an office is. A **department** is a
directory with standing instructions. A **bot** is a chat inside one, with a
job. A **duty** is a job that comes round on its own and asks you when it is
stuck. Nine departments ship with sample data, so every one of these can be
tried before it is set up:

| Department | What ships with it |
| --- | --- |
| **Finance** | Reconcile `ledger.csv` against `statement.csv`; draft one chasing email per overdue customer |
| **Support** | Answer what came in; group the questions by what they are really about |
| **Operations** | List every order still unshipped, with how long it has waited |
| **Marketing** | Turn notes into a week of posts; group contacts by what they bought |
| **People & admin** | Read applicants against a role; pull decisions and owners out of meeting notes |
| **Legal** | Compare their draft against our terms, clause by clause, quoting both |
| **Research** | Summarise where studies agree and where they conflict, and why |
| **Clinical records** | Set out what is recorded and what a clinician should look at, quoting the note |
| **Engineering** | Read a service and report what would give a wrong answer |

Six workflows ship as skills and work in any directory: reviewing a file of
rows against its rules, reporting what changed over a week, triaging an inbox,
comparing two drafts, turning a transcript into decisions and owners, and
reading a set of records for what is worth checking.

---

## Which models actually work

The question nobody else answers. Tool calling is what separates a model that
can do this from one that can only talk about it, and the model card never says.

Each row is one fixed task: a six-row invoice file with three planted problems
— an amount over the limit with no PO number, a blank amount, and a date with a
month of 13 — and a `rules.md` stating the three rules. A pass means all three
found, each quoted against the rule it breaks, with the row number.

| Model | Runtime | Calls tools | Found 3/3 | Notes |
| --- | --- | --- | --- | --- |
| `huihui-qwen3.8-27b` | Ollama, local | yes | yes | Verified by script rather than by eye. Stated the row count from memory and got it wrong by one; the skill now requires that number to come from the script |

This table is short because it only holds what has been run. **Adding a row is
the most useful contribution you can make** — the task is in
[`docs/model-check.md`](./docs/model-check.md), and it takes about five minutes.

---

## What it cannot do

Said here rather than discovered later.

- **General open models reach for `grep` when they have a file tool.** Given a
  structured way to read a file, a model that was not trained toward it will
  still shell out. That is a gap in the models, and no interface closes it.
  What this project can change is reach, not intelligence.
- **The desktop builds are not signed** with an Apple or Microsoft certificate.
  Your operating system will warn you, and it is right to: it cannot tell who
  built them. macOS wants `xattr -dr com.apple.quarantine /Applications/OpenCLI.app`
  once, or right-click → *Open*. Windows SmartScreen wants *More info* → *Run anyway*.
- **Scheduled tasks run only while OpenCLI is open.** It is a local agent, not
  a server. Anything that must fire while the machine sleeps belongs in the
  operating system's scheduler.
- **Token counts are estimated, never counted.** The tokenizer belongs to the
  model, and this runs models it has never seen. Four ASCII bytes to a token,
  one token per character otherwise — close for English and Chinese alike, and
  it errs towards over-counting elsewhere.
- **A background run may write anything inside the directory it runs in.** The
  sandbox's writable root *is* that directory. Runs outside a department's
  directory are held until you allow the place by name.

---

## Install

**Desktop app** — [opencli.ai/download](https://opencli.ai/download.html), or
straight from the latest release:

| Platform             | File                                                                                                                                   |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| macOS, Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg)               |
| macOS, Intel         | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg)                 |
| Windows              | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux                | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage)       |

The app updates itself after that.

**Command line** — one binary, macOS and Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

or with npm, anywhere Node runs:

```shell
npm install -g @ai-dashboad/opencli
```

**From source** — a recent Rust toolchain:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

---

## Point it at a model

A local Ollama needs nothing but this in `~/.opencli/config.toml`:

```toml
model = "qwen3-coder"

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "chat"

[[models]]
slug = "qwen3-coder"
model = "qwen3-coder:30b"
provider = "ollama"
context_window = 32768
```

Then `opencli`. The desktop app can install a local model for you instead —
**Models**, and it looks at what is already on the machine first.

Any OpenAI-compatible endpoint works the same way, hosted or not. For OpenAI
itself, set `OPENAI_API_KEY` and use the built-in `openai` provider. The full
reference is in [docs/config.md](./docs/config.md).

---

## Interface

Ten translations ship with it: English, 简体中文, 繁體中文, 日本語, 한국어,
Español, Português (Brasil), Français, Deutsch and Русский. Each is fetched
when chosen rather than bundled, so nine of them cost you nothing.

Any other language is one JSON file — added through **Customize → Language**,
or dropped in `~/.opencli/locales`. Both write to the same place, so what is
added through the interface can be edited by hand afterwards or copied to
another machine. A file named for a language that already ships corrects
sentences in it rather than replacing the whole translation.

See [docs/languages.md](./docs/languages.md). Right-to-left languages are not
among them yet: that is a change to the stylesheet, not a translation file.

---

## Docs

- [**Configuration**](./docs/config.md) — providers, models, routing, sandboxing
- [**Adding a language**](./docs/languages.md)
- [**Checking a model**](./docs/model-check.md) — the task behind the table above
- [**Contributing**](./docs/contributing.md)
- [**Installing & building**](./docs/install.md)

---

## Where this came from

OpenCLI is a fork of [OpenAI's Codex CLI](https://github.com/openai/codex),
Copyright 2025 OpenAI, Apache-2.0. It is not affiliated with OpenAI.

The fork exists because Codex is built for OpenAI's models and OpenCLI is built
for everybody else's — which changes more than a name. Departments, bots,
duties, background runs and the workflows above are ours. So is a good deal of
work on what breaks when the model is small: a compaction loop that summarised
once a turn for eleven turns and threw away the thread each time, and a token
estimate that read a page of Chinese as three quarters of its real cost.

Licensed under [Apache-2.0](LICENSE). See [NOTICE](NOTICE) for full attribution.
