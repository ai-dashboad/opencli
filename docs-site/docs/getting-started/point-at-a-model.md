---
title: Point it at a model
sidebar_position: 2
---

# Point it at a model

OpenCLI ships with no model and no key. On a fresh install the first screen
says so and offers the two routes below.

This is not a list of integrations — it is one protocol. Anything that answers
`/v1/chat/completions` and `/v1/models` the way OpenAI does can be pointed at,
and **its models appear in the picker on their own**. You do not declare them
one by one.

## On this machine

The desktop app can install one for you: open **Models**, and it looks at what
is already on the machine before offering to fetch anything.

By hand, with [Ollama](https://ollama.com) already running:

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

Put that in `~/.opencli/config.toml` and run `opencli`.

Nothing leaves the machine, and there is no key to keep.

## A provider

Any of them works the same way. The pattern is a base URL and the name of an
environment variable holding the key:

```toml
model = "my-model"

[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

```shell
export MY_PROVIDER_API_KEY=...
opencli
```

In the desktop app the same thing is done in **Settings**, where the key is
stored and never shown again.

### Free allowances are the cheapest way to try a big model

Several providers give something away, which is how you run a model far larger
than your machine could hold. What is free changes month to month, so this
page quotes no amounts — check their own pricing pages.

The [README](https://github.com/ai-dashboad/opencli#where-the-model-comes-from)
carries the full list of providers, each one verified by asking it for its
model list.

## A model may not come from the company that made it

Xiaomi publishes MiMo, ByteDance publishes Seed, and neither runs a public
OpenAI-compatible endpoint of its own. Both are carried by others — so you
reach MiMo through OpenRouter, Novita, DeepInfra, PPIO or Hugging Face, not
through Xiaomi.

## Being reachable is not the same as being good at this

A provider that answers the OpenAI API but not its tool-calling part will chat
and little else: this agent works by calling tools. Before committing to a
model, [check it](/reference/checking-a-model) — five minutes, one fixed task.

## Next

[Your first conversation](/getting-started/first-conversation).
