# Architecture

How OpenCLI is put together, and why. This is the document to read before
changing something and wondering whether the current shape was deliberate.

It is deliberately opinionated about *boundaries* — what a layer may claim to
do — because most of the bugs worth recording here were a layer claiming
something it could not deliver.

---

## The one idea

**OpenCLI does not run inference.** It talks to an OpenAI-compatible HTTP
endpoint. Everything else follows from that:

- Choosing a model means writing down where it is served, not loading weights.
- "Install a model" is an instruction to some *runtime*, not something this
  program does.
- Whether a feature is possible depends on what that runtime exposes, and on
  whether it is on this machine.

Losing sight of this produces features that look reasonable and do nothing.

---

## Pieces

```
opencli-rs/
  core/           the agent: config, tools, sandbox, sessions, rollouts
  app-server/     JSON-RPC 2.0 over stdio; one conversation at a time
  web-gateway/    WebSocket ↔ app-server, plus everything that outlives a chat
  ssh/            enough SSH to install and repair a runtime elsewhere
  api/            wire adapters: Responses, Chat Completions, Anthropic
  cli/, tui/      the terminal front ends
web/              the browser and desktop interface
desktop/          Tauri shell; runs the gateway in-process
```

### Why the gateway owns so much

The app server is scoped to **one conversation**. Anything that outlives a
conversation is answered by the gateway instead of relayed:

| Concern | Why it cannot live in the app server |
| --- | --- |
| Projects, memory | Apply across conversations |
| Scheduled tasks, dispatch | Run when no conversation is open |
| Connectors, plugins, servers | Edit files on this machine |
| Model management | Talks to a runtime, not to a model |

The gateway intercepts these methods before relaying anything to stdin. A
handler returning `None` means "not mine" and the message passes through.

---

## Capability tiers

The most important table in this document. Three ways to reach a machine, and
they answer different questions:

| Tier | What it can do | What it cannot |
| --- | --- | --- |
| **HTTP** | list, install, remove models; inference | install or repair the runtime itself |
| **SSH** | install a runtime into a home directory, start it, read logs | anything needing root |
| **SSH + root** | system services, drivers, firewall | — |

Consequences that shaped the UI:

- **Only Ollama exposes model downloading over HTTP.** That is the whole reason
  "install this model on the server" works without a shell there. `core/runtimes.rs`
  records this as data with a test asserting it, so if another runtime gains
  such an API the change is recorded rather than drifting.
- **A runtime that cannot be driven remotely must say what to run instead.**
  Enforced by a test. A dead button is worse than a sentence.
- **sudo cannot be automated.** When a repair needs root, the command is shown.
  Asking a user to paste a root password into an app is not an improvement.

### SSH

Built in rather than shelling out to `ssh`, at the user's request. That choice
carries obligations, and they are met in `ssh/`:

- **Host keys are checked before anything is sent.** `Unknown` and `Changed` are
  different questions: the first asks, showing the fingerprint; the second
  refuses and does *not* offer to overwrite. Either the server was rebuilt —
  which deserves a human — or something is in the middle, which no dialog
  should make easy to click past.
- **Nothing is stored.** Aliases resolve against the user's own
  `~/.ssh/config`; keys come from the agent first, then the usual files. The
  only thing ever written back is a host key the user agreed to trust. A test
  asserts the server store contains no credential-shaped fields.

---

## Data, not code

Anything a user might reasonably want to change ships as data:

| Catalogue | Location | User's own |
| --- | --- | --- |
| Providers | `core/src/providers/catalog/*.toml` | `config.toml` |
| Models | `core/src/model_catalog/entries/*.toml` | `~/.opencli/models.toml` |
| Connectors | `web-gateway/src/connector.rs` | `config.toml` |
| Plugins | `web-gateway/src/plugin.rs` | `~/.opencli/skills/` |

The model catalogue was hardcoded first and it was wrong: the same kind of
thing was data in one place and code in another, for no reason anyone could
state, and extending it meant a rebuild. A user entry replaces a bundled one
with the same tag *whole*, rather than merging field by field — a
half-overridden entry is harder to reason about than a replaced one. Bundled
entries can be shadowed but not deleted, so a build's own catalogue stays
intact.

### Where state lives

Under `~/.opencli/`:

```
config.toml        providers, models, connectors, settings
models.toml        catalogue entries the user added
projects.json      directories, standing instructions, thread grouping
memory.json        facts injected into every new thread
scheduled.json     recurring prompts
dispatch.json      background runs and their output
servers.json       model servers: URL, and optionally an ssh alias
sessions/          conversation transcripts
skills/            installed skills
```

Every store follows the same rules: a missing or corrupt file yields an empty
list rather than an error, and nothing lives *only* in one of these files. A
lost `projects.json` costs the grouping, never a conversation.

---

## Wire protocols

`WireApi` decides how a request is shaped:

| Variant | Endpoint | Notes |
| --- | --- | --- |
| `Responses` | `/v1/responses` | OpenAI's newer API |
| `Chat` | `/v1/chat/completions` | What almost every local runtime speaks |
| `Anthropic` | `/v1/messages` | Not OpenAI-compatible; own request and event shapes |

Anthropic needed more than a URL: a top-level `system` field, a required
`max_tokens`, `input_schema` tools, and `x-api-key` rather than a bearer token.
That last one made the shared header helper wire-aware, which touches every
provider — covered by a test asserting bearer auth is unchanged for `Chat`.

`web_search` is declared but has **no local handler**: it is executed by the
provider. Offering it to a runtime that does not run it hands the model a tool
nobody answers, so the UI says where it works.

---

## Approvals

Every non-safe command is surfaced before it runs. Three things learned the
hard way:

- **The decision values are `accept` and `decline`.** An unparseable decision
  is not reported as an error — the command simply never runs. Sending
  `approved` looked correct and silently did nothing.
- **`on-request` means "the model decides"**, and in practice it almost never
  asks. It is not offered in Customize: a security setting that reads as
  "never" to someone who chose it expecting to be consulted is the wrong way
  round.
- **A file-change approval does not carry its own contents.** They arrive on
  the earlier `item/started` for the same item id. Without correlating, the
  user is asked to approve writes they cannot see.

---

## Front end

`web/` serves both the browser and the desktop build; the difference is that
the desktop hosts the gateway in-process and can reach the platform's file
dialogs.

- **`protocol.ts` is the only place that knows the wire format.** It has tests
  driven through a fake socket using payload shapes captured from a live
  server, not invented ones.
- **`openSession` and `startThread` are separate.** A thread's instructions
  must be settled before it starts, and working out which memories apply itself
  needs a connected socket.
- **A new chat is a new thread, not a new connection.** Reconnecting drops the
  socket and sends the app back to its starting screen, which reads as the
  window reopening.
- **Enter is not "send" while an input method is composing.** It confirms a
  candidate; swallowing it makes Chinese, Japanese and Korean input impossible.

---

## Recurring failure

Nearly every bug worth recording here is the same shape: **a control that looks
live and is not.**

The model picker that never sent its value. The chat list that filtered itself
empty. The approval that sent a word the server ignored. The skill menu that
listed skills and did nothing. The window that could not be dragged because a
permission was never granted, and failed silently because that is what an
ungranted Tauri capability does.

The habits that catch these:

1. **Verify against the real thing.** Both bugs in the SSH client — the exit
   status arriving after `Eof`, and a quoting test asserting a substring that
   legitimately appears — were invisible to a mock and obvious against a real
   server.
2. **Say what cannot be done.** A runtime with no download API gets a sentence,
   not a button. A hub that cannot report tool support says so rather than
   guessing at the one fact that decides usefulness.
3. **Make the constraint data.** "Only Ollama can be driven remotely" is a
   table with a test, not a condition at a call site, so it cannot quietly
   become untrue.

---

## Known limits

Stated plainly rather than discovered later:

- **Local models often ignore structured file tools.** Given `search_text` and
  `open_file`, several still reach for `bash grep` unless told otherwise. That
  is model training, not harness design, and a different front end will not
  change it.
- **A model that cannot call tools is close to useless here.** The catalogue
  says so per entry; hub search leaves it unstated because only the runtime
  knows.
- **The Anthropic adapter has never run against a valid key.** With an invalid
  one the endpoint returns 401 rather than 400, which shows the URL, method,
  body and headers are accepted — the strongest check available without one.
- **A config change reaches a chat when the chat starts.** Registering a model
  or toggling a connector applies to the next conversation, and the UI says so.
- **Speech input is not implemented.** WKWebView has no Web Speech API, and a
  transcription backend is a dependency not yet chosen. No microphone button is
  shown rather than one that does nothing.
