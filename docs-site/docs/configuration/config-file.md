---
title: The configuration file
sidebar_position: 1
---

# The configuration file

`~/.opencli/config.toml`. Everything here has a default; the file only holds
what you have changed.

The desktop app writes the same file, keeping your comments and formatting, so
editing by hand and editing in **Settings** are the same act.

## Providers and models

A provider is a base URL and the name of an environment variable holding the
key:

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

Models declared under it appear in the picker:

```toml
model = "my-model"

[[models]]
slug = "my-model"
model = "provider-side-model-id"
provider = "my-provider"
display_name = "My Model"
context_window = 128000
reasoning_efforts = ["low", "medium", "high"]
```

`slug` is what you type; `model` is what the provider calls it. They differ
often enough to be worth separating.

**You do not have to declare them.** Models are fetched from the provider's
`/v1/models`. Declaring one is for pinning a context window, a display name,
or the efforts it accepts.

## Approvals and sandbox

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

Explained in [Sandbox and approvals](/configuration/sandbox-and-approvals).

## Tool output

```toml
tool_output_token_limit = 10000
```

A budget for what a tool's output may add to the conversation.

**Tokens are estimated, not counted.** The tokenizer belongs to the model, and
this runs models it has never seen. The estimate is four ASCII bytes to a
token and one token per character otherwise — close for English and Chinese
alike, erring towards over-counting elsewhere. Setting this to 500 does not
cut at exactly 500 tokens; it cuts near it, in the same units the number is
written in.

## Seeing what is in effect

**Settings** shows every value that applies and where it came from, including
the ones you have never set. `Show raw config` is the file itself.

## The full reference

Every key, with its default:
[docs/config.md](https://github.com/ai-dashboad/opencli/blob/main/docs/config.md).
