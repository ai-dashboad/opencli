# Configuration

For basic configuration instructions, see [this documentation](https://github.com/ai-dashboad/opencli/blob/main/docs/config.md).

For advanced configuration instructions, see [this documentation](https://github.com/ai-dashboad/opencli/blob/main/docs/config.md).

For a full configuration reference, see [this documentation](https://github.com/ai-dashboad/opencli/blob/main/docs/config.md).

## Quickest path: let OpenCLI find your models

If you already run Ollama, LM Studio, vLLM, or llama.cpp locally:

```shell
opencli provider scan
```

This probes the usual localhost ports, asks each server it finds which models it
serves, and writes the matching `[model_providers.*]` and `[[models]]` sections
into your `config.toml` — existing comments and settings are preserved. Add
`--dry-run` to see what it would write first.

For hosted providers, install one from the catalog and set its key:

```shell
opencli provider list          # catalog plus what is already configured
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

The catalog only carries connection details — no keys ship with the binary, and
nothing is active until you add it. To configure something not in the catalog,
write the sections by hand as described below.

### Filling in a model's capabilities

A local model's context window and tool-calling support are not published
anywhere, and guessing them is worse than leaving them unset — too large a
context window means the provider rejects turns instead of auto-compacting.
Ask the model instead:

```shell
opencli model probe <slug>            # add --dry-run to preview
```

This reads the runtime's own metadata where available (Ollama reports the real
context length and capability list) and additionally makes one live request to
see whether the model calls an offered tool and whether it returns its thinking
in a separate `reasoning` field. Findings are written into the model's
`[[models]]` entry.

Models that cannot chat at all — embedding models, for instance — are skipped by
`provider scan`, so they never reach the `/model` picker.

## Choosing models and providers

This build ships presets for several gateways, but any model reachable over an
OpenAI-compatible API can be configured in `~/.opencli/config.toml` without
rebuilding.

### Adding a provider

Entries in `[model_providers.<id>]` override a built-in provider of the same id,
so this is also how you repoint a bundled gateway at a proxy or mirror:

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# Optional: raise if this gateway is slow to produce a first token.
stream_idle_timeout_ms = 90000
```

API keys are always read from the environment; they are never stored in the
config file.

### Adding a model

Declare models with `[[models]]`. They appear in the `/model` picker next to the
built-in presets, and an entry whose `model` matches a built-in preset replaces
it:

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # optional, defaults to the slug
description = "Self-hosted."   # optional
show_in_picker = true          # optional, defaults to true
```

`provider` is required and must name a provider defined above or a built-in one;
a model pointing at an undefined provider is rejected at startup rather than
failing later with an unrelated error.

To select a model without adding it to the picker, set `model` and
`model_provider` directly:

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

If `model` names something that is neither a built-in preset nor a `[[models]]`
entry and `model_provider` is unset, requests fall back to the `openai` provider
and a warning is logged.

### Context windows

Models this build has no metadata for start with a conservative 131,072-token
window and learn the real one from the gateway's first context-window rejection.
Set `model_context_window` to pin it explicitly.

## Connecting to MCP servers

OpenCLI can connect to MCP servers configured in `~/.opencli/config.toml`. See the configuration reference for the latest MCP server options:

- https://github.com/ai-dashboad/opencli/blob/main/docs/config.md

## Apps (Connectors)

Use `$` in the composer to insert a ChatGPT connector; the popover lists accessible
apps. The `/apps` command lists available and installed apps. Connected apps appear first
and are labeled as connected; others are marked as can be installed.

## Notify

OpenCLI can run a notification hook when the agent finishes a turn. See the configuration reference for the latest notification settings:

- https://github.com/ai-dashboad/opencli/blob/main/docs/config.md

## JSON Schema

The generated JSON Schema for `config.toml` lives at `opencli-rs/core/config.schema.json`.

## Notices

OpenCLI stores "do not show again" flags for some UI prompts under the `[notice]` table.

Ctrl+C/Ctrl+D quitting uses a ~1 second double-press hint (`ctrl + c again to quit`).
