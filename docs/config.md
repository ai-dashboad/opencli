# Configuration

For basic configuration instructions, see [this documentation](https://developers.openai.com/opencli/config-basic).

For advanced configuration instructions, see [this documentation](https://developers.openai.com/opencli/config-advanced).

For a full configuration reference, see [this documentation](https://developers.openai.com/opencli/config-reference).

## Connecting to MCP servers

OpenCLI can connect to MCP servers configured in `~/.opencli/config.toml`. See the configuration reference for the latest MCP server options:

- https://developers.openai.com/opencli/config-reference

## Apps (Connectors)

Use `$` in the composer to insert a ChatGPT connector; the popover lists accessible
apps. The `/apps` command lists available and installed apps. Connected apps appear first
and are labeled as connected; others are marked as can be installed.

## Notify

OpenCLI can run a notification hook when the agent finishes a turn. See the configuration reference for the latest notification settings:

- https://developers.openai.com/opencli/config-reference

## JSON Schema

The generated JSON Schema for `config.toml` lives at `opencli-rs/core/config.schema.json`.

## Notices

OpenCLI stores "do not show again" flags for some UI prompts under the `[notice]` table.

Ctrl+C/Ctrl+D quitting uses a ~1 second double-press hint (`ctrl + c again to quit`).
