<p align="center">
  <img src="website/public/favicon.svg" width="72" alt="OpenCLI" />
</p>

<h3 align="center">The agent for the models that do not have one</h3>

<p align="center">
  <a href="https://docs.opencli.ai"><b>Documentation</b></a> ·
  <a href="https://opencli.ai/download.html"><b>Download</b></a> ·
  <a href="./README.zh-CN.md"><b>中文</b></a>
</p>

---

Claude has Claude Code. OpenAI has Codex. Gemini has its CLI. The models you
can actually run — Qwen, DeepSeek, GLM, Llama, MiMo — have none.

**OpenCLI is theirs.** A terminal agent and a desktop app that point at
whatever OpenAI-compatible endpoint you like: a model on the machine in front
of you, your own gateway, or a hosted provider when you want one. It ships with
no models, no accounts and no keys.

## Install

```shell
curl -fsSL https://opencli.ai/install.sh | sh    # macOS and Linux
npm install -g @ai-dashboad/opencli              # anywhere Node runs
```

Desktop app for macOS, Windows and Linux:
[opencli.ai/download](https://opencli.ai/download.html). The builds are not
signed, so your operating system will warn you the first time —
[what to do](https://docs.opencli.ai/getting-started/install).

Then [point it at a model](https://docs.opencli.ai/getting-started/point-at-a-model).

## It is not only for code

The agent reads files, runs commands and edits things. That is as true of a
folder of invoices as it is of a repository, and most of the work people
actually have is the first kind.

So the desktop app is organised the way an office is. A **department** is a
directory with standing instructions. A **bot** is a chat inside one, with a
job. A **duty** is a job that comes round on its own and asks you when it is
stuck.

Nine departments ship with sample data — finance, support, operations,
marketing, people, legal, research, clinical records, engineering — so each can
be tried before it is set up. Six workflows ship as skills and work anywhere:
reviewing rows against their rules, reporting what changed over a week,
triaging an inbox, comparing two drafts, turning a transcript into decisions
and owners, and reading records for what is worth checking.

→ [Departments and bots](https://docs.opencli.ai/doing-work/departments-and-bots)

## Where the model comes from

One protocol, not a list of integrations: anything answering
`/v1/chat/completions` and `/v1/models` the way OpenAI does can be pointed at,
and its models appear on their own.

Forty-odd providers have been checked by asking each one for its model list —
local runtimes, self-hosted serving, the open-model hosts, the Chinese
providers, and the closed models. Several give a free allowance, which is the
cheapest way to try a model larger than your machine can hold.

→ [Providers](https://docs.opencli.ai/getting-started/providers)

## Which models actually work

Being reachable is not the same as being good at this. Tool calling is what
separates a model that can do this work from one that can only talk about it,
and the model card never says.

One fixed task, five minutes, and the table has one row because one model has
been run. **Adding a row is the most useful contribution you can make.**

→ [Checking a model](https://docs.opencli.ai/reference/checking-a-model)

## What it cannot do

- **General open models reach for `grep` when they have a file tool.** A gap in
  the models; no interface closes it.
- **Token counts are estimated, never counted.** The tokenizer belongs to the
  model, and this runs models it has never seen.
- **Scheduled work runs only while OpenCLI is open.** A local agent, not a
  server.
- **A background run may write anything inside the directory it runs in.** The
  sandbox's writable root *is* that directory.
- **The desktop builds are not signed.** Your operating system is right to warn
  you.

→ [Limits](https://docs.opencli.ai/reference/limits), which says why for each.

## Where this came from

A fork of [OpenAI's Codex CLI](https://github.com/openai/codex), Copyright 2025
OpenAI, Apache-2.0. **Not affiliated with OpenAI.**

Codex is built for OpenAI's models and this is built for everybody else's,
which changes more than a name. Departments, bots, duties, background runs and
the workflows are ours, as is a good deal of work on what breaks when the model
is small — a compaction loop that summarised once a turn for eleven turns, and
a token estimate that read a page of Chinese as three quarters of its cost.

Licensed under [Apache-2.0](LICENSE). See [NOTICE](NOTICE) for full
attribution. Contributions:
[CONTRIBUTING](https://docs.opencli.ai/reference/contributing).
