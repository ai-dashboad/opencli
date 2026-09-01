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

Every non-safe command is surfaced before it runs. Four things learned the
hard way:

- **The policy is a turn option, not a thread one.** Sent only at
  `thread/start`, changing it mid-conversation did nothing — the worst way for
  a security control to be wrong, because it looks as though it took. It is now
  sent on every turn, and offered beside the model picker: a run of commands is
  exactly when someone decides they have seen enough of them, and walking to
  another panel then starting a new chat is long enough that they approve
  twenty more instead.


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

## Models are the subject, machines are a detail

The Models page was first built machine-first: pick a machine, see what is on
it. That is the shape of the API — probe a URL, list its models — and letting
it become the shape of the interface was a mistake. Someone with models on a
laptop and a GPU box could not see what they owned without switching between
them, and had to choose a machine before knowing what they wanted.

It is now model-first:

- **Installed** is every model on every machine, in one list, each row naming
  where it lives. All machines are asked at once; one that is down contributes
  nothing rather than emptying the list.
- **Browse** is the library and the hubs, scoped to no machine at all. A row
  says what a model needs, not whether it fits somewhere in particular.
- **The machine is chosen when installing**, in the same dialog as the version.

Those last two belong together because one determines the other: the best
quantisation depends on the memory of the machine picked, so changing the
machine changes what is recommended. Splitting them across two steps would ask
the second question before its answer could be known.

### Browsing, not searching

Hugging Face was reachable only by typing a name into a search box. That asks
someone to already know what a model is called, which is the thing they came to
find out. The panel opened empty and stayed empty until they guessed.

So the popular list is fetched **with no query at all** — most downloaded first
— cached to disk, and warmed by a background task when the gateway starts. The
panel opens on a browsable list of a hundred models; typing narrows it rather
than being the way in. Nothing is filtered by taste: everything Hugging Face
reports as popular is shown, in its order. The one filter is `pipeline_tag`,
which removes embedding and speech models — not a judgement about quality, but
about whether a thing can hold a conversation at all.

The cache is served even when old, marked as refreshing rather than withheld.
Waiting on a network call would reintroduce the empty panel this exists to
prevent.

The same reasoning applies to the install dialog. It first read every machine's
memory over SSH before rendering, which took six seconds against one remote
server — six seconds of a dialog that said "looking at your machines" and
offered nothing. The machine list is now gathered by the panel while the user
browses, and memory is read for the one machine chosen, after the dialog is
already usable.

Two consequences that read as small and are not:

- **Already having a model does not disable installing it.** Having it on one
  machine is a reason to want it on another. The row says where it already is;
  only the dialog, where a machine is named, can refuse a duplicate.
- **An unknown machine gets the balanced version, not the largest.** Memory is
  only readable where there is an SSH alias. Treating "unknown" as "it fits"
  ranked the largest file top — the worst guess for a machine nothing is known
  about.

---

## Nothing may be silent

Three reports of "this button does not work" turned out to be three different
kinds of silence, none of them a broken handler.

- **A picker that changed a label and nothing else.** The model was sent on
  `thread/start` only, so choosing another mid-conversation was decorative.
  `turn/start` accepts one and applies it to that turn and the ones after; it
  is now sent on every turn.
- **A step nobody could see.** Installing a model puts a file on a machine;
  the picker offers what `config.toml` names. Seven installed and two offered,
  with nothing on screen explaining the difference, reads as a broken picker.
  Each installed row now says whether a chat can select it. The provider id is
  derived in the gateway, so the rule for turning an address into a provider
  lives in one place.
- **Buttons that worked but said nothing for eight seconds.** Remove waited on
  a fresh look at every machine before the row disappeared. Rows now report
  what they are doing, say it beside the row rather than at the top of the
  panel where it scrolls out of sight, and drop themselves immediately while
  the refresh runs behind.

### Show what is known, then what is slow

Measuring every panel found almost all of them answer from a local file in
under three milliseconds. Only three were slow, and each for the same reason:
one call that reaches over the network was awaited together with the fast ones,
so opening the panel cost the slowest thing in it.

| Panel | Was | Now | The slow part |
| --- | --- | --- | --- |
| Models | 4.7 s blank | first rows in 25 ms | `/api/show`, 2.5 s per model on a remote server |
| Connectors | 2.2 s blank | rows at once | starting each MCP server to see if it answers |
| Browse | network-bound | 1 ms | Hugging Face, now warmed at startup |

The rule that came out of it: **a panel shows what it already knows, and fills
in what costs a round trip.** A machine on this computer lists its models in
milliseconds while one across the internet takes a second and a half; holding
the first for the second is a choice, not a necessity.

What a model can do is also cached for the life of the gateway. A tag
identifies weights, so its context length and tool support cannot change
underneath it — only by the model being replaced, which happens through an
install or a removal, and both drop the entry.

### One slow answer must not delay the others

The gateway read one message, awaited its handler, then read the next. Every
request on a connection therefore queued behind the one before it: the panel
asks all its machines at once, and the answers still arrived one at a time.
Listing every model took 7.7 seconds against a single remote server.

Methods under `server/`, `hub/` and `runtime/` reach over the network and are
now answered on their own task. Ownership is decided from the method name
before any work is done, because the loop must know whether to answer or relay
without first paying to find out. Replies carry their own id, so arriving out
of order is what the protocol already expects. Everything else stays in the
loop: a turn must reach stdin in the order it was sent.

---

## Width belongs to the content, not to the panel

Panels were once a fixed column centred beside the sidebar, then a fixed
column left-aligned. Both were the same mistake with a different number: one
figure cannot serve a paragraph, a card and a diff at the same time. At
1040px a remembered note was wider than is comfortable to read, a model card
was wider than it needed, and on a 1920 display 560px sat empty.

Each kind of content now states its own limit:

| Content | Limit | Why |
| --- | --- | --- |
| Prose | `68ch` | A line of 1600px is measurably harder to read; the eye loses its place returning |
| Card lists | `repeat(auto-fill, minmax(420px, 1fr))` | As many columns as fit — two at 1200px, three at 1900, four at 2560 |
| Diffs, run output, notes | one column, `1040px` | Splitting these would halve the width of the one thing in them that needs it |

`auto-fill` rather than a column count, so the number follows the window and
no display size is ever named. 420px was measured against the longest thing a
card holds — a tag like `huihui-qwen3.8-27b:latest` above a line of size,
memory and context — which at 360px filled the card edge to edge.

The chat fills the window. It was a centred 780px, then a capped 1180px, and
both left a wide display mostly empty; the owner asked for the width to be
used, so `--chat-width` is `100%` and nothing inside it is capped either.

This is a deliberate trade against one thing: on a very wide display a
paragraph becomes a very long line, and a long line is harder to read because
the eye loses its place returning to the next one. Restoring a measure means
putting `max-width` back on `.item.agent pre` alone — the code blocks should
keep the full width regardless, since a wrapped diff is worse than a wide one.

The transcript, the composer, the approval box and the footer all read the
same `--chat-width`. They are stacked, so a few pixels of difference between
them reads as misalignment.

---

## Saying what a turn cost

Nothing in the interface could report tokens or elapsed time, and the reason
went three layers deep — each layer looked like it worked.

1. **The provider was never asked.** The Chat request sent `"stream": true`
   without `stream_options: { include_usage: true }`, so a streaming server
   sends no usage at all. Servers that do not know the field ignore it, so
   asking costs nothing.
2. **The answer was thrown away.** The Chat SSE parser hardcoded
   `token_usage: None`. The chunk carrying the cost has an *empty* `choices`
   array and arrives *after* the one that says the reply is finished, so
   completing on `finish_reason` discarded it. Completion now happens at the
   stream's end — which the tool-call path already relied on — carrying
   whatever the provider reported.
3. **The client listened for the wrong name.** The server emits the older
   `opencli/event/token_count`, snake_case under `msg.info`; the client was
   written against the v2 `thread/tokenUsage/updated`, camelCase under
   `tokenUsage`. It now reads both.

Elapsed time is counted client-side while a turn runs. On a local model a
reply can take minutes, and a spinner that says only "Working…" cannot be
told apart from one that has hung — which is exactly how the fault below was
first reported.

### Streaming was off for every local model

A reply arriving in one lump after minutes of a spinner turned out to be four
faults stacked, each of which looked deliberate:

1. **One flag did two jobs.** `client.rs` chose `aggregate()` over
   `streaming_mode()` for the Chat wire whenever `show_raw_agent_reasoning`
   was false — and `AggregateMode::AggregatedOnly` swallows the *answer*
   deltas as well as the thinking. Whether to show a model's reasoning and
   whether the answer arrives a word at a time are different questions; every
   local model speaks Chat, so every local model had streaming off by default.
   The answer now always streams; the flag governs only the thinking.
2. **The client never listened.** It handled `item/started` and
   `item/completed` and nothing between them.
3. **Thinking is a separate event.** Ollama streams a reasoning model's
   thoughts as `delta.reasoning` while `delta.content` stays `""`. Those
   arrive as `item/reasoning/textDelta`, which is now shown — and can be
   hidden — separately from the answer.
4. **An empty delta is not an update.** Every reasoning chunk carries
   `content: ""`; treating that as text would blank the message each time.

### A proxy in front of the model has its own clock

The turn also could not finish, for two reasons that compounded:

- **Our own idle timeout was 90 seconds**, on the reasoning that a stream
  silent that long is wedged. It is not: nothing arrives at all while a model
  reads the prompt, and an 11,700-token agent prompt on a CPU takes about
  three minutes. Silence before the first event now gets four times the
  allowance of a gap during one.
- **Cloudflare gives up at about 127 seconds** and answers 524. Measured both
  ways: the identical request returned 524 after 127s through the tunnel and
  200 after 232s through an SSH tunnel to the same machine. Retrying sends the
  same request and waits the same time, so gateway timeouts (504, 522, 524)
  are no longer retried — eight attempts was a quarter of an hour of
  guaranteed failure.

### Slowness is usually not the harness

A 27B model answering at 1.6 tokens per second turned out to be a GPU that
another process had filled: `nvidia-smi` showed 28.9 GB of 32 GB held by an
unrelated vLLM engine, leaving Ollama to run a 27 GB model almost entirely on
the CPU — `/api/ps` reported `size_vram` of 293 MB against a `size` of 27.1
GB. Neither figure was visible anywhere in the interface, so the only symptom
was a spinner.

`size_vram` against `size` is the check worth reaching for first: it answers
"is this model actually on the card" in one request. Ollama's own log is
blunter still — `offloaded 0/66 layers to GPU`, alongside the
`available="2.2 GiB"` it measured at load time.

Freeing the card and reloading turned the same work from 254 seconds into 10:
prompt reading from 114.5s to 3.4s, generation from 1.36 to 57.9 tokens per
second. Nothing in this program changed; the model simply stopped running on
the CPU.

### Two numbers answer to "context window"

`/api/show` reports what the weights were *trained* to hold; the server is
started with `-c` and may serve far less. For the model here those are 262,144
and 32,768 — a factor of eight. Registering the trained figure meant the agent
never compacted and the server rejected the turn at an eighth of the size it
had been told it had. The smaller of the two is the only safe answer, and a
loaded model is the only thing that can report it.

---

## An item that carries no text still carries something

Three item kinds have now been dropped by the same emptiness check, each for
the same reason and each found only by someone noticing the transcript was
missing things it should have had.

| Item | Where its content is |
| --- | --- |
| File change | `changes`, as a list of paths and diffs |
| Command | `command`, with what it printed in `aggregatedOutput` |
| MCP tool call | `server` and `tool`, with the answer in `result` |

None of them has a `text` field, so a converter looking for one concluded
they carried nothing and returned null. The visible symptom the third time
was a transcript of nothing but the agent's own narration, every paragraph
of it stamped with the agent's name — because narration was the only thing
left in it.

The check itself is right and stays: it is what keeps housekeeping items out
of the transcript. What was wrong was asking only one question of every kind
of item.

---

## Markdown, rendered without a renderer

Agent replies are Markdown and were shown verbatim, so a summary arrived as
its own asterisks and backticks. `web/src/markdown.tsx` renders the part of
it an agent actually writes: emphasis, code spans, fenced blocks, lists,
headings and links.

**It produces React elements, never HTML strings.** That is the whole safety
argument — nothing in it can turn a model's output into markup, so there is
no injection to sanitise against and no sanitiser to get wrong. The one place
a value reaches an attribute is a link's `href`, which is why only `http` and
`https` survive it; anything else is shown as the words the model wrote.

Deliberately partial, and deliberately no dependency: this package has two,
React and React DOM. Tables, block quotes, images and nested lists are shown
as the text they are, because a table rendered wrongly is harder to read than
one not rendered at all.

Commands keep their `<pre>`. A shell line with an asterisk in it means the
asterisk.

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
4. **A file being the right shape does not make it the right file.** A GGUF
   repository holds companions beside the weights: `mmproj-…` is a vision
   projector, a real `.gguf`, carrying a quantisation in its name at a
   fortieth of the model's size. Read as a choice it looked like the best
   version that fits, and was recommended — an Install button that downloads
   something which cannot answer a prompt. Found only by listing what a real
   repository actually contains.

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
- **Not every Hugging Face repository can be installed.** Some hold GGUF files
  under names this build cannot read a quantisation from. The install dialog
  says so and refuses rather than offering a version that does not exist;
  roughly one row in eight of the popular list is affected.
- **Speech input is not implemented.** WKWebView has no Web Speech API, and a
  transcription backend is a dependency not yet chosen. No microphone button is
  shown rather than one that does nothing.
