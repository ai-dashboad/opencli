/**
 * Client for the `opencli app-server` JSON-RPC protocol, spoken over the
 * WebSocket that `opencli serve` exposes.
 *
 * The wire format is JSON-RPC 2.0 with the `"jsonrpc"` header omitted: requests
 * carry an `id` and get exactly one response; notifications have a `method` and
 * no `id`, and arrive unsolicited while a turn runs.
 */

export type RequestId = number;

export interface RpcResponse {
  id: RequestId;
  result?: unknown;
  error?: { code: number; message: string };
}

export interface RpcNotification {
  method: string;
  params?: unknown;
}

type Incoming = RpcResponse & Partial<RpcNotification>;

/** One file the agent added, edited, or deleted. */
export interface FileChange {
  path: string;
  /** `add`, `delete`, or `update`. */
  kind: string;
  /** Unified diff of what changed. */
  diff: string;
}

/** A turn item as surfaced to the UI. */
export interface ThreadItem {
  id: string;
  kind:
    | "user"
    | "agent"
    | "command"
    | "reasoning"
    | "fileChange"
    | "other"
    | "wait"
    | "total"
    | "compaction";
  text: string;
  /** Present for command items once the command has finished. */
  exitCode?: number;
  /** Present for file-change items: what was written, and the diff. */
  changes?: FileChange[];
  /** What a command printed, or what a tool returned. */
  output?: string;
  /** How long it took, once it is over. */
  durationMs?: number;
  /** Which tool ran: a shell, or an MCP server's tool. */
  tool?: string;
  /**
   * What the command does, in a few words.
   *
   * The model's own `description` when it wrote one, and otherwise worked out
   * from the server's parse of the command. A local model often leaves an
   * optional field empty, so the parse is not a fallback that rarely runs — it
   * is the usual case.
   */
  summary?: string;
}

export interface ClientEvents {
  onItem?: (item: ThreadItem) => void;
  /**
   * A message being written, sent again each time it grows.
   *
   * Covers the agent's answer and its thinking alike: a reasoning model can
   * think for minutes before writing a word, and that whole time it is the
   * only thing there is to show.
   */
  onItemDelta?: (item: ThreadItem) => void;
  /** A turn has begun, in the conversation it names. */
  onTurnStart?: (threadId: string | null) => void;
  onTurnComplete?: () => void;
  onError?: (message: string) => void;
  /**
   * A failed attempt that is being retried, and what it said.
   *
   * Not an error: the turn is still alive. It is reported because a request
   * that fails and is retried eight times is otherwise eighteen minutes of a
   * spinner with nothing to explain it.
   */
  onRetry?: (attempt: string, reason: string) => void;
  /**
   * Something the agent is doing that is not a message: compacting the
   * conversation, mostly.
   *
   * The server has always said it. Nothing listened, so a compaction — which
   * takes half a minute on a local model and holds up the whole turn — looked
   * exactly like the model being slow.
   */
  onNotice?: (text: string, progress?: { done: number; total: number }) => void;
  /**
   * Whether the conversation is being summarised right now.
   *
   * Its own signal because it is not the model writing: the status line said
   * "Writing…" through the whole of it, which was simply the wrong word.
   */
  onCompacting?: (on: boolean) => void;
  /** The agent is asking permission to run something. */
  onApprovalRequest?: (request: ApprovalRequest) => void;
  /** A model download reported progress. */
  onPullProgress?: (progress: PullProgress) => void;
  /** The running total of tokens this conversation has cost. */
  onTokenUsage?: (usage: TokenUsage) => void;
  onStatus?: (status: ConnectionStatus) => void;
}

export interface ApprovalRequest {
  /** The request id to answer with. */
  id: RequestId;
  /** The conversation that raised it, so it is only shown there. */
  threadId?: string;
  /** What is being asked for: running a command, or writing files. */
  kind: "command" | "fileChange";
  /** The command line, for a command approval. */
  command?: string;
  cwd?: string;
  /** Why the agent needs approval, when the server explains it. */
  reason?: string;
  /** The files about to be written, for a file-change approval. */
  changes?: FileChange[];
}

/** A model offered by the configured providers. */
export interface ModelOption {
  id: string;
  model: string;
  displayName: string;
  description: string;
  reasoningEfforts: string[];
}


/** A credential the agent can use, described without ever carrying its value. */
export interface SecretStatus {
  /** The environment variable's name, e.g. `OPENAI_API_KEY`. */
  name: string;
  /** Whether OpenCLI has it written down. */
  stored: boolean;
  /** Whether the surrounding environment already exports it, which wins. */
  fromEnvironment: boolean;
}

/** A stored conversation, as listed in the sidebar. */
export interface ThreadSummary {
  id: string;
  preview: string;
  updatedAt: number;
  name?: string;
}

/** What a bot is doing, as far as anyone watching can tell. */
export type BotStatus = "idle" | "working" | "waitingForYou" | "errored";

/** A conversation that keeps a job. */
export interface Bot {
  id: string;
  /** The department it works in, by id. */
  department: string;
  departmentName: string;
  name: string;
  /** What it is for. Re-sent as instructions whenever its chat is reopened. */
  job: string;
  /** The conversation that is this bot, once it has had one. */
  threadId: string | null;
  status: BotStatus;
  /** How another bot refers to it: `finance/reconciler`. */
  address: string;
  createdAt: number;
  updatedAt: number;
}

/** A skill available in the current working directory. */
export interface SkillSummary {
  name: string;
  description: string;
  /** Where it lives; the server needs this to invoke it, not just the name. */
  path: string;
  enabled: boolean;
}

/** A recurring task, run by the gateway while it is up. */
export interface ScheduledTask {
  id: string;
  name: string;
  prompt: string;
  intervalSeconds: number;
  cwd: string;
  lastRun: number | null;
  nextRun: number | null;
  /** How many times it has run, ever. */
  runCount: number;
  enabled: boolean;
}

/** A workspace: a directory, standing instructions, and its threads. */
export interface Project {
  id: string;
  name: string;
  cwd: string;
  /** What the project is, for the card. Distinct from `instructions`. */
  description: string;
  /** Standing instructions given to the agent in every thread here. */
  instructions: string;
  createdAt: number;
  updatedAt: number;
  pinned: boolean;
  threadIds: string[];
}

/** A fact the user asked the agent to remember. */
export interface Memory {
  id: string;
  text: string;
  /** The project it is scoped to; `null` means every conversation. */
  projectId: string | null;
  createdAt: number;
}

/** Where a background run came from. */
export type RunSource = "dispatch" | "cowork" | "scheduled";

export type RunStatus = "queued" | "running" | "done" | "failed" | "cancelled";

/** Work the agent is doing, or has done, without the chat waiting on it. */
export interface Run {
  id: string;
  title: string;
  prompt: string;
  cwd: string;
  model: string | null;
  source: RunSource;
  status: RunStatus;
  startedAt: number;
  finishedAt: number | null;
  output: string;
  exitCode: number | null;
  taskId: string | null;
}

/** A configured MCP server and whether it is usable. */
export interface ConnectorSummary {
  name: string;
  toolCount: number;
  status: string;
  /** What the server offers, when it answered the handshake. */
  tools: string[];
}

/**
 * Something sent alongside a message.
 *
 * An image is inlined as a data URL, because a browser `File` has no path to
 * refer to. A file is named in the message text instead: the agent reads it
 * with the tools it already has, and a large file would otherwise be pasted
 * into the context whether or not it was needed.
 */
export type Attachment =
  | { kind: "image"; name: string; dataUrl: string }
  | { kind: "file"; name: string; path: string }
  | { kind: "skill"; name: string; path: string };

/** How the agent should read: the two personalities the server accepts. */
export type Personality = "friendly" | "pragmatic";

/** How hard the model should think, when it supports being told. */
export type ReasoningEffort = "none" | "minimal" | "low" | "medium" | "high" | "xhigh";

/**
 * When the agent must ask before acting.
 *
 * `untrusted` asks for every command that is not known-safe. `on-request`
 * leaves it to the model, which in practice almost never asks — so it reads as
 * "never" to a user who picked it expecting to be consulted.
 */
export type ApprovalPolicy = "untrusted" | "on-failure" | "on-request" | "never";

/** Per-thread preferences the user can change. */
export type Appearance = "system" | "dark" | "light";
/** `null` follows the browser's language list. */
export type LanguageChoice = "system" | "en" | "zh";
export type TextSize = "normal" | "large" | "larger";

export interface Preferences {
  personality?: Personality;
  /** Which palette to use; "system" follows the operating system. */
  appearance?: Appearance;
  /** How large the conversation's text is. */
  textSize?: TextSize;
  /** Which language the interface is in. */
  language?: LanguageChoice;
  effort?: ReasoningEffort;
  approvalPolicy: ApprovalPolicy;
  /**
   * Ask the model to summarise its reasoning.
   *
   * Named for what it does. The reference calls this "Thinking", but the
   * setting behind it only decides whether a *summary* is requested — the
   * model thinks either way, and a toggle implying otherwise would be a lie
   * about what turning it off saves.
   */
  showThinking?: boolean;
  /**
   * Offer the web search tool.
   *
   * The tool is executed by the provider, not by OpenCLI — there is no local
   * handler for it. Turning it on for a provider that does not run it gives
   * the model a tool nobody answers, so the UI says where it works.
   */
  webSearch?: boolean;
  /**
   * Ask for thorough, multi-source investigation before answering.
   *
   * This is instructions, not a retrieval pipeline: it changes how the agent
   * is told to work, and is only as good as the tools it already has.
   */
  research?: boolean;
}

/** A machine that serves models. */
export interface ServerEntry {
  id: string;
  name: string;
  baseUrl: string;
  runtime: string;
  /** An alias from ~/.ssh/config, when this machine can also be reached by shell. */
  sshAlias: string | null;
  createdAt: number;
}

/** A host the user's own ssh config already names. */
export interface SshAlias {
  alias: string;
  hostname: string;
  port: number;
  user: string | null;
  /** Directives this client does not act on, so they can be reported. */
  unsupported: string[];
}

/** A runtime found on this machine. */
export interface DiscoveredRuntime {
  runtime: string;
  name: string;
  baseUrl: string;
  version: string | null;
  /** Whether models can be installed through it, or only served. */
  manageable: boolean;
}

/** What a close look at a server found. */
export interface Diagnosis {
  http: { reachable: boolean; version?: string; status?: number };
  shell: {
    os: string;
    binary: string;
    service: string;
    enabled: string;
    restarts: number;
    listeningLocally: boolean;
    modelsOnDisk: string;
    diskFree: string;
    gpu: string;
    canSudo: boolean;
    user: string;
  } | null;
  findings: string[];
}

/** A model on offer, from a library or a hub search. */
export interface Offer {
  source: "ollama" | "huggingface";
  /** What it is for, which is how the library groups entries. */
  purpose?: string;
  /** What to pull. Whatever the source, this goes to the runtime unchanged. */
  tag: string;
  name: string;
  note?: string;
  sizeGb?: number;
  needsGb?: number;
  /** Null when only the runtime can say, which is true of hub results. */
  tools: boolean | null;
  context?: number;
  downloads?: number;
  fits?: boolean;
  needsQuant?: boolean;
  /** Entries the user added, which are the ones they may edit or remove. */
  userDefined?: boolean;
}

/** A local inference runtime and what it can be asked to do. */
export interface RuntimeInfo {
  id: string;
  name: string;
  defaultPort: number;
  acquisition: "remoteApi" | "localFile" | "launchArgument" | "ownInterface";
  listsModels: boolean;
  deletesModels: boolean;
  /** Whether a machine elsewhere can be told to fetch a model over HTTP. */
  canDownloadRemotely: boolean;
  remoteNote: string;
  docs: string;
}

/** What answered at an address. */
export interface RuntimeProbe {
  reachable: boolean;
  version?: string;
  isLocal?: boolean;
  status?: number;
  detail?: string;
}

/** A model, and the machine it is installed on. */
export interface ModelLocation {
  /** The machine, as the user named it. */
  server: string;
  baseUrl: string;
  /** Whether the runtime there can be told to remove it. */
  manageable: boolean;
  model: InstalledModel;
  capabilities?: ModelCapabilities;
}

/** A machine models can be installed to. */
export interface InstallTarget {
  label: string;
  baseUrl: string;
  reachable: boolean;
  /** Memory available to models, when it can be read. Null when it cannot. */
  memoryGb: number | null;
  /** Models already there, so a duplicate install can be pointed out. */
  installed: string[];
}

/** A model installed on a runtime. */
export interface InstalledModel {
  name: string;
  size: number;
  parameterSize?: string;
  quantization?: string;
  family?: string;
  modifiedAt?: string;
}

/** What a model can do, which decides whether it is usable here. */
export interface ModelCapabilities {
  model: string;
  capabilities: string[];
  supportsTools: boolean;
  contextLength: number | null;
}

/** One quantisation of a model, with what choosing it costs. */
export interface ModelVariant {
  quant: string;
  /** The tag to install, already assembled. */
  tag: string;
  sizeGb: number;
  /** What this quantisation costs, in words rather than letters. */
  note: string;
  /** Null when the machine's memory is unknown. */
  fits: boolean | null;
}

/**
 * What a conversation has cost so far.
 *
 * The server has always reported this; nothing listened. Without it a slow
 * model is indistinguishable from a stuck one, and how close a conversation
 * is to filling its context — which is what triggers compaction — is
 * invisible until it happens.
 */
export interface TokenUsage {
  /** Everything this conversation has spent. */
  total: number;
  /** The most recent turn alone. */
  last: number;
  input: number;
  output: number;
  /** What the model can hold, when the server knows it. */
  contextWindow: number | null;
}

/** Progress while a model downloads. */
export interface PullProgress {
  model: string;
  /** The machine it is being installed on, so a finish can be acted upon. */
  baseUrl?: string;
  status?: string;
  completed?: number;
  total?: number;
  done?: boolean;
  error?: string;
}

/** One entry at the top of a project's directory. */
export interface ProjectFile {
  name: string;
  isDir: boolean;
  size: number;
}

/** A skill installed under the home directory. */
export interface InstalledPlugin {
  name: string;
  description: string;
  path: string;
}

/** A skill offered by name, with where it comes from. */
export interface PluginOffer {
  id: string;
  name: string;
  description: string;
  source: string;
  note?: string;
}

/** A connector as configured on this machine. */
export interface ConnectorConfig {
  name: string;
  enabled: boolean;
  transport: {
    kind: "stdio" | "http";
    command?: string;
    args?: string[];
    url?: string;
    /**
     * Environment variables passed through to the server, by name. The values
     * live with the other keys and never appear here.
     */
    envVars?: string[];
  };
}

/** A connector offered by name, with how it is started. */
export interface ConnectorOffer {
  id: string;
  name: string;
  description: string;
  transport: {
    kind: "stdio" | "http";
    command?: string;
    args?: string[];
    url?: string;
    envVars?: string[];
  };
  note?: string;
  /** The variable this server needs a value for, when it needs one. */
  keyHint?: string;
}

export type ConnectionStatus = "connecting" | "ready" | "closed" | "error";

/**
 * Extract readable text from the several shapes the server uses for item
 * payloads. Kept tolerant on purpose: the protocol carries many item types and
 * a UI that throws on an unfamiliar one is worse than one that shows nothing.
 */
function textOf(value: unknown): string {
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return value.map(textOf).filter(Boolean).join("");
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    for (const key of ["text", "message", "content", "delta"]) {
      if (key in record) {
        const nested = textOf(record[key]);
        if (nested) return nested;
      }
    }
  }
  return "";
}

/**
 * How far through a job of known length, when the note says.
 *
 * Both ends of this are ours: the phrase is written by `compact.rs`, which
 * counts the pieces a long conversation is cut into. A note that does not
 * carry one — most of them — leaves the reader with words alone, which is
 * right: a bar that moves at a made-up rate is a lie told smoothly.
 */
function stepsIn(text: string): { done: number; total: number } | undefined {
  const found = /\bpart (\d+) of (\d+)\b/.exec(text);
  if (!found) return undefined;
  const done = Number(found[1]);
  const total = Number(found[2]);
  if (!Number.isFinite(done) || !Number.isFinite(total) || total < 1) return undefined;
  return { done, total };
}

/**
 * What an error actually said.
 *
 * The text is nested under `msg`, one level below where the reader of the
 * payload looked, so every failure arrived as the same six words: a model
 * that does not exist, a conversation past its context window and an endpoint
 * that is down were indistinguishable. The server had sent the reason in full
 * each time.
 */
function errorText(payload: unknown): string {
  const record = (payload ?? {}) as Record<string, unknown>;
  const turn = record.turn as Record<string, unknown> | undefined;
  return (
    textOf(record.msg) ||
    textOf(record) ||
    textOf(turn?.error) ||
    "the agent reported an error"
  );
}

/**
 * Read the `changes` array of a file-change item.
 *
 * These items carry no text at all, so without this they are dropped by the
 * emptiness check below and the UI never shows that a file was written.
 */
function changesOf(item: Record<string, unknown>): FileChange[] {
  if (!Array.isArray(item.changes)) return [];
  return item.changes.flatMap((raw) => {
    const change = raw as Record<string, unknown>;
    const path = typeof change.path === "string" ? change.path : "";
    if (!path) return [];
    // `kind` is a tagged union — `{ type: "add" }` — not a bare string.
    const kind =
      typeof change.kind === "string"
        ? change.kind
        : String((change.kind as Record<string, unknown> | undefined)?.type ?? "update");
    return [{ path, kind, diff: typeof change.diff === "string" ? change.diff : "" }];
  });
}

function classify(item: Record<string, unknown>): ThreadItem["kind"] {
  const type = String(item.type ?? item.itemType ?? "");
  if (type.includes("agentMessage") || type.includes("agent_message")) return "agent";
  if (type.includes("userMessage") || type.includes("user_message")) return "user";
  if (type.includes("command") || type.includes("exec")) return "command";
  if (type.includes("mcpToolCall") || type.includes("mcp_tool_call")) return "command";
  if (type.includes("reasoning")) return "reasoning";
  if (type.includes("fileChange") || type.includes("file_change")) return "fileChange";
  return "other";
}

/**
 * A stable identity for an item, since the server does not always give one.
 *
 * Reasoning arrives with `id: ""` — the field is not serialised for this wire
 * and no provider fills it — so every thought in a conversation shared the
 * same empty id, and nothing could be matched to anything. Worse, the same
 * thought is sent twice: `started`, `completed`, `started`, `completed`, the
 * second pair carrying the finished text from the outset. Appending what
 * arrives showed every thought twice.
 *
 * Deriving the id from the content makes the repeat *be* the same item, so it
 * replaces rather than accumulating. Two genuinely identical consecutive
 * thoughts collapse into one, which is the right answer for them too.
 */
function identify(item: Record<string, unknown>, kind: ThreadItem["kind"], text: string): string {
  const given = typeof item.id === "string" ? item.id.trim() : "";
  if (given) return given;

  let hash = 5381;
  for (let at = 0; at < text.length; at += 1) {
    hash = ((hash << 5) + hash + text.charCodeAt(at)) | 0;
  }
  return `${kind}:${(hash >>> 0).toString(36)}`;
}

/**
 * The agent's own tools, named for a reader rather than for the agent.
 *
 * `open_file` is what the model calls it. A row headed `open_file` with
 * `open_file` underneath tells someone watching nothing they did not already
 * see — the name of the tool is not the interesting part, the file is.
 *
 * `argument` is the field worth showing; a tool not listed here keeps its own
 * name, because inventing a friendly one for a tool this build has never
 * heard of would be guessing.
 */
const AGENT_TOOLS: Record<string, { label: string; argument: string }> = {
  open_file: { label: "Read a file", argument: "path" },
  browse_dir: { label: "List a directory", argument: "path" },
  search_text: { label: "Search", argument: "query" },
  apply_patch: { label: "Edit files", argument: "path" },
  web_search: { label: "Search the web", argument: "query" },
  update_plan: { label: "Update the plan", argument: "explanation" },
  view_image: { label: "Look at an image", argument: "path" },
};

/**
 * What a tool call should say: a name a reader knows, and the thing it acted
 * on. Falls back to the tool's own name and a compact view of its arguments.
 */
function describeTool(
  name: string,
  args: unknown,
): { label: string; detail: string } {
  const record = (args ?? {}) as Record<string, unknown>;
  const known = AGENT_TOOLS[name];

  if (known) {
    const value = record[known.argument];
    return {
      label: known.label,
      detail: typeof value === "string" && value ? value : name,
    };
  }

  /*
   * A tool nobody here has heard of is written as words rather than as an
   * identifier: `list_resources` becomes "List resources".
   *
   * This invents no meaning — they are the tool's own words, only readable.
   * Leaving them as an identifier put jargon in front of someone watching,
   * and a curated name for a tool this build has never seen would be a guess.
   */
  const pairs = Object.entries(record)
    .filter(([, value]) => typeof value === "string" || typeof value === "number")
    .map(([key, value]) => `${key}: ${value}`);
  return { label: asWords(name), detail: pairs.join("  ") || asWords(name) };
}

/** `list_resources` → `List resources`, and `getDesignContext` likewise. */
function asWords(name: string): string {
  const spaced = name
    .replace(/[_-]+/g, " ")
    .replace(/([a-z\d])([A-Z])/g, "$1 $2")
    .trim()
    .toLowerCase();
  return spaced ? spaced[0].toUpperCase() + spaced.slice(1) : name;
}

/**
 * Put the server's parse of a command into words.
 *
 * `commandActions` is a best-effort reading of what a shell line will do:
 * reading a file, listing a directory, searching. It is what makes a row say
 * "Read markdown.tsx" instead of repeating a line of shell nobody scans.
 *
 * A command is often several joined together, so only the first recognised
 * action is used — a row is a glance, and three clauses is not one.
 */
function describeActions(actions: unknown): string {
  if (!Array.isArray(actions)) return "";
  for (const raw of actions) {
    const action = raw as Record<string, unknown>;
    const type = String(action.type ?? "");
    const name = typeof action.name === "string" ? action.name : "";
    const path = typeof action.path === "string" ? action.path : "";
    const query = typeof action.query === "string" ? action.query : "";

    if (type === "read") return `Read ${name || path}`;
    if (type === "listFiles" || type === "list_files") {
      return path ? `List ${path}` : "List files";
    }
    if (type === "search") {
      if (query && path) return `Search ${path} for “${query}”`;
      if (query) return `Search for “${query}”`;
      return "Search";
    }
  }
  return "";
}

/**
 * Convert one server item into what the UI renders, or `null` if it carries
 * nothing to show.
 *
 * Shared by the live stream and by replayed history: stored turns use the same
 * item shapes, and having two converters would let the two drift.
 */
function toThreadItem(item: Record<string, unknown>): ThreadItem | null {
  const changes = changesOf(item);

  /*
   * A command and a tool call carry no `text` at all.
   *
   * The command line lives in `command` and what it printed in
   * `aggregatedOutput`; an MCP call names a `server` and a `tool`. Looking only
   * for `text` found neither, so every one of them was judged to be carrying
   * nothing and dropped — the transcript showed the agent's narration about
   * running commands and never the commands. Exactly the fault file changes
   * had, which is why `changesOf` already exists beside this.
   */
  const type = String(item.type ?? item.itemType ?? "");
  const command = typeof item.command === "string" ? item.command : "";
  const isTool = type.includes("mcpToolCall") || type.includes("mcp_tool_call");
  const server = typeof item.server === "string" ? item.server : "";
  const toolName = typeof item.tool === "string" ? item.tool : "";
  const described = isTool ? describeTool(toolName, item.arguments) : null;

  // An MCP server's tool is named by its server; one of the agent's own is
  // named for what it does. An empty server is not a name, and joining it
  // produced a leading " · ".
  // The server is kept so it is clear where the call went, but the tool is
  // named for the reader either way: `opencli · list_resources` says where and
  // says nothing about what.
  const tool = described
    ? server
      ? `${server} · ${described.label}`
      : described.label
    : undefined;

  const text =
    command ||
    (described ? described.detail : "") ||
    textOf(item) ||
    changes.map((change) => `${change.kind} ${change.path}`).join("\n");
  if (!text) return null;

  const summary =
    (typeof item.description === "string" && item.description.trim()) ||
    describeActions(item.commandActions) ||
    undefined;

  const output =
    (typeof item.aggregatedOutput === "string" ? item.aggregatedOutput : "") ||
    (isTool ? textOf(item.result) : "") ||
    undefined;
  const kind = classify(item);
  return {
    summary,
    output,
    durationMs: typeof item.durationMs === "number" ? item.durationMs : undefined,
    tool,
    id: identify(item, kind, text),
    kind,
    text,
    exitCode: typeof item.exitCode === "number" ? item.exitCode : undefined,
    ...(changes.length > 0 ? { changes } : {}),
  };
}

export class OpenCliClient {
  #socket: WebSocket | null = null;
  #nextId = 1;
  #pending = new Map<RequestId, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();
  #events: ClientEvents;
  #threadId: string | null = null;
  /**
   * File changes seen on `item/started`, keyed by item id.
   *
   * A file-change approval arrives moments later carrying only the id, so the
   * contents have to be held from the start notification to describe it.
   */
  /**
   * Messages still being written, keyed by the id they are streaming under.
   *
   * The kind is kept alongside the text because a finished message arrives
   * under a *different* id from the one it streamed as, and matching it back
   * to what is on screen is done by kind.
   */
  #streaming = new Map<string, { kind: ThreadItem["kind"]; text: string }>();
  /**
   * When the current turn's request went out, and whether the wait it opened
   * has been closed yet.
   *
   * A turn's time is not one span but several, and the first of them — the
   * model reading the conversation before it says anything — was invisible.
   * It is measured from here to whatever comes back first.
   */
  #turnBegan: number | null = null;
  #waitShown = false;
  /** When the compaction now running began, so its row can say how long. */
  #compactingSince: number | null = null;
  /** When each piece of thinking began, so its length can be reported. */
  /**
   * The thought being thought right now, if any.
   *
   * Not keyed on the server's id, because the server does not give one: a
   * reasoning item's `item/started` and `item/completed` both carry an empty
   * id, and only its deltas carry a real one. Keyed on the empty string, three
   * thoughts in a turn shared one entry — the first counted up forever because
   * nothing ever closed it, and the two after it finished with no time at all.
   *
   * Thoughts do not overlap, so one open thought at a time is the whole truth.
   */
  #thought: { id: string; began: number; text: string } | null = null;
  #thoughtCount = 0;
  /**
   * The answer being written right now, identified here for the same reason a
   * thought is: the id on a delta is the server's to change, and a row is
   * created per id. One reply is written at a time.
   */
  #writing: { id: string; text: string } | null = null;
  #writingCount = 0;
  /**
   * The thought that just finished.
   *
   * The server sends each one twice — once in the fragments it streamed as,
   * once whole — and the repeat arrives after the thought is closed. Held so
   * it lands on the row already on screen instead of beside it.
   */
  #lastThought: { id: string; text: string } | null = null;
  /**
   * Which id a piece of content is already shown under.
   *
   * An item the server gives no id for is keyed by its content, and the same
   * content is sent more than once — but the first copy may have landed under
   * the id it streamed under. Without this the repeat is appended beside it.
   */
  #shownAs = new Map<string, string>();
  /** The thread the agent has actually been given, if any. */
  #loadedThreadId: string | null = null;
  /**
   * A bot's job, held until the thread is actually loaded.
   *
   * Opening a chat only reads it; the load is deferred to the first message.
   * The job has to travel with that load, so it waits here rather than being
   * sent at a moment when there is nothing to send it to.
   */
  #standingInstructions: string | null = null;
  #pendingChanges = new Map<string, FileChange[]>();

  constructor(events: ClientEvents = {}) {
    this.#events = events;
  }

  get threadId(): string | null {
    return this.#threadId;
  }

  /**
   * Open the socket and complete the handshake, without starting a thread.
   *
   * Split from [`startThread`] because a thread's instructions have to be
   * settled before it starts, and working out what they are — reading the
   * applicable memories — itself needs a connected socket.
   */
  async openSession(url: string): Promise<void> {
    this.#events.onStatus?.("connecting");
    await this.#open(url);
    await this.request("initialize", {
      clientInfo: { name: "opencli_web", title: "OpenCLI Web", version: "0.1.0" },
    });
    this.notify("initialized");
  }

  /** Start a thread on an already-open session. */
  async startThread(options: {
    cwd: string;
    model?: string;
    instructions?: string;
    preferences?: Preferences;
  }): Promise<void> {
    // A thread this client starts is already the agent's; nothing to load.
    const started = (await this.request("thread/start", {
      cwd: options.cwd,
      ...(options.model ? { model: options.model } : {}),
      ...(options.preferences?.personality
        ? { personality: options.preferences.personality }
        : {}),
      // Per-thread config overrides. `live` is the mode that actually queries;
      // `disabled` removes the tool rather than leaving it declared and unused.
      config: { web_search: options.preferences?.webSearch ? "live" : "disabled" },
      // `developerInstructions` appends a message to the context;
      // `baseInstructions` would *replace* the whole system prompt and cost the
      // agent its normal operating rules. Projects and memory add context, so
      // append.
      ...(options.instructions?.trim()
        ? { developerInstructions: options.instructions.trim() }
        : {}),
      // Approvals are surfaced in the UI rather than auto-granted; the agent
      // runs on the machine hosting the gateway.
      approvalPolicy: options.preferences?.approvalPolicy ?? "untrusted",
      sandbox: "workspace-write",
    })) as { thread?: { id?: string }; threadId?: string };

    this.#threadId = started.thread?.id ?? started.threadId ?? null;
    this.#loadedThreadId = this.#threadId;
    // Already sent with the start; holding onto it would send it twice on the
    // next reconnect.
    this.#standingInstructions = null;
    if (!this.#threadId) throw new Error("server did not return a thread id");
    this.#events.onStatus?.("ready");
  }

  /** Connect, complete the handshake, and open a thread. */
  async connect(
    url: string,
    options: { cwd: string; model?: string; instructions?: string; preferences?: Preferences },
  ): Promise<void> {
    await this.openSession(url);
    await this.startThread(options);
  }

  #open(url: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const socket = new WebSocket(url);
      this.#socket = socket;
      socket.onopen = () => resolve();
      socket.onerror = () => {
        this.#events.onStatus?.("error");
        reject(new Error("could not connect; check the URL and token"));
      };
      socket.onclose = () => this.#events.onStatus?.("closed");
      socket.onmessage = (event) => this.#dispatch(String(event.data));
    });
  }

  #dispatch(raw: string): void {
    let message: Incoming;
    try {
      message = JSON.parse(raw) as Incoming;
    } catch {
      return;
    }

    // Responses to our own requests.
    if (typeof message.id === "number" && !message.method) {
      const pending = this.#pending.get(message.id);
      if (pending) {
        this.#pending.delete(message.id);
        if (message.error) pending.reject(new Error(message.error.message));
        else pending.resolve(message.result);
      }
      return;
    }

    // A server-initiated request: it carries both an id and a method, and the
    // server blocks until answered. Observed live as
    // `item/commandExecution/requestApproval` — matching on the substring
    // "approval" missed it, because the word only appears capitalised inside
    // `requestApproval`.
    if (typeof message.id === "number" && message.method) {
      if (/requestApproval$/i.test(message.method)) {
        const params = (message.params ?? {}) as Record<string, unknown>;
        const reason = typeof params.reason === "string" ? params.reason : undefined;
        const cwd = typeof params.cwd === "string" ? params.cwd : undefined;
        // Which conversation is asking. One agent serves them all, so without
        // this an approval raised in one chat is shown in whichever chat
        // happens to be on screen — and approved without its context.
        const threadId = typeof params.threadId === "string" ? params.threadId : undefined;

        if (message.method.includes("fileChange")) {
          // A file-change approval names the item but does not repeat what is
          // in it. The changes arrived earlier, on the `item/started` for the
          // same id — without that lookup the user is asked to approve writes
          // they cannot see.
          const itemId = typeof params.itemId === "string" ? params.itemId : "";
          this.#events.onApprovalRequest?.({
            id: message.id,
            threadId,
            kind: "fileChange",
            changes: this.#pendingChanges.get(itemId) ?? [],
            reason,
            cwd,
          });
          return;
        }

        this.#events.onApprovalRequest?.({
          id: message.id,
          threadId,
          kind: "command",
          command:
            (typeof params.command === "string" ? params.command : textOf(params.command)) ||
            "(unknown command)",
          reason,
          cwd,
        });
      }
      return;
    }

    this.#handleNotification(message.method ?? "", message.params);
  }

  /** Begin a thought, closing any that was somehow left open. */
  #openThought(): { id: string; began: number; text: string } {
    this.#thoughtCount += 1;
    this.#thought = { id: `thought:${this.#thoughtCount}`, began: Date.now(), text: "" };
    return this.#thought;
  }

  /**
   * End the span between sending a turn and hearing anything back.
   *
   * The reader's own message does not end it: the server echoes that back
   * within milliseconds of the turn starting, long before the model has read
   * anything. Only something the model produced means the wait is over.
   */
  #closeTheWait(kind: ThreadItem["kind"]): void {
    if (this.#waitShown || this.#turnBegan === null || kind === "user") return;
    this.#waitShown = true;
    this.#events.onItem?.({
      id: `wait:${this.#turnBegan}`,
      kind: "wait",
      text: "",
      durationMs: Date.now() - this.#turnBegan,
    });
  }

  #handleNotification(method: string, params: unknown): void {
    const payload = (params ?? {}) as Record<string, unknown>;

    /*
     * The server says when a turn begins, and it is the only thing that knows.
     *
     * The clock was started by `send` instead, so it never restarted for a
     * turn the agent began itself — a follow-up after a tool call — and the
     * elapsed time accumulated across all of them into one growing number.
     */
    if (method === "turn/started") {
      this.#turnBegan = Date.now();
      this.#waitShown = false;
      this.#events.onTurnStart?.(
        typeof payload.threadId === "string" ? payload.threadId : this.#threadId,
      );
      return;
    }
    if (method === "turn/completed" || method === "opencli/event/task_complete") {
      // What the whole turn cost, kept in the transcript rather than lost with
      // the running clock: the phases above it only add up if the total is
      // there to add them against.
      if (this.#turnBegan !== null) {
        this.#events.onItem?.({
          id: `total:${this.#turnBegan}`,
          kind: "total",
          text: "",
          durationMs: Date.now() - this.#turnBegan,
        });
        this.#turnBegan = null;
      }
      this.#events.onTurnComplete?.();
      return;
    }
    if (method === "item/started") {
      // Not rendered — see below — but a file change's contents are only sent
      // here, and an approval for it follows within moments.
      const item = (payload.item ?? payload) as Record<string, unknown>;
      const changes = changesOf(item);
      if (changes.length > 0 && typeof item.id === "string") {
        this.#pendingChanges.set(item.id, changes);
      }
      /*
       * Thinking is timed from here, not from its first delta.
       *
       * The server sends no duration for reasoning, so it is measured. Timing
       * from the first delta lost every thought that finished before one
       * arrived — and those showed a bare "Thinking" that never said how long
       * it had taken, which is the one thing the row exists to say.
       */
      if (item.type === "contextCompaction") {
        this.#compactingSince = Date.now();
        this.#events.onCompacting?.(true);
        return;
      }
      const beginning = classify(item);
      if (beginning === "reasoning") {
        // Timed from here rather than from the first delta: a thought that
        // finishes before one arrives still has to say how long it took.
        this.#openThought();
      }
      this.#closeTheWait(beginning);
      return;
    }
    // Only `item/completed` is rendered. `item/started` carries the same item
    // moments earlier — for a user message with identical content, and for an
    // agent message with empty text *and a different id*, so it can be neither
    // deduplicated by id nor shown. Waiting for completion is what actually
    // yields one correct entry per item.
    /*
     * Text as it is written, rather than only when it is finished.
     *
     * Without this a reply appears in one lump at the end. On a fast model
     * that reads as a pause; on a local one it is minutes of a spinner with
     * nothing to show for it, which is indistinguishable from a hang.
     */
    if (method === "item/agentMessage/delta" || method === "item/reasoning/textDelta") {
      const kind: ThreadItem["kind"] =
        method === "item/reasoning/textDelta" ? "reasoning" : "agent";
      const delta = payload.delta as string | undefined;
      // An empty delta is not nothing happening — a reasoning model sends
      // `content: ""` alongside every thought — but there is nothing to add.
      if (!delta) return;
      this.#closeTheWait(kind);

      /*
       * A thought is identified here, not by the server.
       *
       * Its `item/started` and `item/completed` both carry an empty id and
       * only its deltas carry a real one, and the first of those is empty too.
       * Following the server's ids meant three thoughts in a turn shared one
       * key: the first counted up forever and the rest finished untimed. One
       * open thought at a time is the whole truth, because they do not
       * overlap.
       */
      if (kind === "reasoning") {
        const open = this.#thought ?? this.#openThought();
        open.text += delta;
        this.#events.onItemDelta?.({ id: open.id, kind, text: open.text });
        return;
      }

      /*
       * And so is the answer, for the same reason.
       *
       * Keyed on the id the server put on each delta, a reply whose id
       * changed part-way — an empty one first and a real one after, which is
       * exactly what a thought does — became two rows. Every fragment landing
       * under a fresh id would make a row per word.
       */
      if (!this.#writing) {
        this.#writingCount += 1;
        this.#writing = { id: `answer:${this.#writingCount}`, text: "" };
      }
      this.#writing.text += delta;
      this.#events.onItemDelta?.({ id: this.#writing.id, kind, text: this.#writing.text });
      return;
    }
    if (method === "item/completed") {
      const raw = (payload.item ?? payload) as Record<string, unknown>;
      if (typeof raw.id === "string") this.#pendingChanges.delete(raw.id);

      if (raw.type === "contextCompaction") {
        const began = this.#compactingSince;
        this.#compactingSince = null;
        this.#events.onCompacting?.(false);
        // A span of the turn like the others, kept in the transcript: a
        // conversation that was summarised should say so afterwards, or a
        // reader wonders where the earlier detail went.
        this.#events.onItem?.({
          id: `compaction:${began ?? Date.now()}`,
          kind: "compaction",
          text: "",
          ...(began ? { durationMs: Date.now() - began } : {}),
        });
        return;
      }

      const item = toThreadItem(raw);
      if (!item) return;
      // A command can be the first thing a turn produces, and it arrives
      // finished — no `item/started`, no deltas — so the wait must end here
      // too or it would never be closed at all.
      this.#closeTheWait(item.kind);

      /*
       * A finished thought closes the one that is open, whatever id the
       * server put on it — which is none. This is also the only moment its
       * duration is known, because nothing sends one.
       */
      if (item.kind === "agent" && this.#writing) {
        const open = this.#writing;
        this.#writing = null;
        this.#events.onItem?.({ ...item, id: open.id });
        return;
      }

      if (item.kind === "reasoning") {
        const open = this.#thought;
        this.#thought = null;
        if (open) {
          const closed = { ...item, id: open.id, durationMs: Date.now() - open.began };
          this.#lastThought = { id: open.id, text: item.text };
          this.#events.onItem?.(closed);
          return;
        }
        // The repeat of the thought that just finished, landing on the row it
        // is already on rather than beside it.
        if (this.#lastThought?.text === item.text) {
          this.#events.onItem?.({ ...item, id: this.#lastThought.id });
          return;
        }
        this.#events.onItem?.(item);
        return;
      }

      /*
       * A finished message arrives under a different id from the one it
       * streamed under — `item/started` says `8ec3a8e8`, `item/completed`
       * says `c3eb8a74` for the same reply. Emitting it as it came left the
       * streamed copy on screen and appended the finished one beside it, so
       * every paragraph appeared twice.
       *
       * It is handed back under the id already on screen, which is matched by
       * kind: only one message of a kind is ever being written at a time.
       */
      /*
       * An item with no id of its own is identified by its content, and the
       * same content arriving twice must land on the id already on screen —
       * which may be neither: a thought first appears under the id it streamed
       * under, and its repeat has only the derived one. Remembering which id a
       * piece of content was shown under is what ties the three together.
       */
      const shownAs = this.#shownAs.get(item.id);
      if (shownAs) {
        this.#streaming.delete(item.id);
        this.#events.onItem?.({ ...item, id: shownAs });
        return;
      }

      if (!this.#streaming.has(item.id)) {
        for (const [openId, open] of this.#streaming) {
          if (open.kind === item.kind) {
            this.#streaming.delete(openId);
            this.#shownAs.set(item.id, openId);
            this.#events.onItem?.({ ...item, id: openId });
            return;
          }
        }
      }

      this.#streaming.delete(item.id);
      this.#shownAs.set(item.id, item.id);
      this.#events.onItem?.(item);
      return;
    }
    if (method === "runtime/pull/progress") {
      this.#events.onPullProgress?.(payload as unknown as PullProgress);
      return;
    }
    // Two spellings of the same fact. The v2 notification is camelCase and
    // nested under `tokenUsage`; the event the server actually sends today is
    // the older `token_count`, snake_case and nested under `msg.info`. Reading
    // only the newer one meant reading nothing at all.
    if (method === "thread/tokenUsage/updated" || method === "opencli/event/token_count") {
      const record = payload as Record<string, unknown>;
      const info = (record.tokenUsage ??
        (record.msg as Record<string, unknown> | undefined)?.info) as
        | Record<string, Record<string, number> | number | null>
        | undefined;
      if (!info) return;

      const total = (info.total ?? info.total_token_usage) as Record<string, number> | undefined;
      const last = (info.last ?? info.last_token_usage) as Record<string, number> | undefined;
      const window = (info.modelContextWindow ?? info.model_context_window) as number | null;
      const pick = (from: Record<string, number> | undefined, camel: string, snake: string) =>
        from?.[camel] ?? from?.[snake] ?? 0;

      this.#events.onTokenUsage?.({
        total: pick(total, "totalTokens", "total_tokens"),
        last: pick(last, "totalTokens", "total_tokens"),
        input: pick(last, "inputTokens", "input_tokens"),
        output: pick(last, "outputTokens", "output_tokens"),
        contextWindow: window ?? null,
      });
      return;
    }
    if (method === "opencli/event/background_event") {
      const nested = (payload.msg ?? payload) as Record<string, unknown>;
      const text = typeof nested.message === "string" ? nested.message : "";
      if (text) this.#events.onNotice?.(text, stepsIn(text));
      return;
    }
    // A retry, not a failure: the attempt is over, the turn is not. Matched
    // before the error test below, which would otherwise claim the turn had
    // died each time one was retried.
    if (method === "opencli/event/stream_error") {
      const nested = (payload.msg ?? payload) as Record<string, unknown>;
      const attempt = typeof nested.message === "string" ? nested.message : "Retrying";
      const detail =
        typeof nested.additional_details === "string" ? nested.additional_details : "";
      this.#events.onRetry?.(attempt, detail);
      return;
    }
    if (method.endsWith("/error") || method === "opencli/event/error") {
      this.#events.onError?.(errorText(payload));
    }
  }

  request(method: string, params?: unknown): Promise<unknown> {
    const socket = this.#socket;
    if (!socket) return Promise.reject(new Error("not connected"));
    const id = this.#nextId++;
    return new Promise((resolve, reject) => {
      this.#pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ method, id, ...(params ? { params } : {}) }));
    });
  }

  notify(method: string, params?: unknown): void {
    this.#socket?.send(JSON.stringify({ method, ...(params ? { params } : {}) }));
  }

  /**
   * Send a user message and begin a turn.
   *
   * Effort, summary and model are turn options rather than thread ones, so
   * they are passed here — changing one takes effect on the next message
   * rather than needing a new chat.
   *
   * The model was previously sent only on `thread/start`, which made the
   * picker decorative once a conversation had begun: choosing a different one
   * changed the label and nothing else. The server accepts it per turn and
   * applies it to this turn and the ones after.
   */
  async send(
    text: string,
    options: {
      effort?: ReasoningEffort;
      attachments?: Attachment[];
      /** `auto` asks for a reasoning summary; `none` does not. */
      summary?: "auto" | "none";
      model?: string;
      /** When the agent should stop and ask. Applies from this turn on. */
      approvalPolicy?: ApprovalPolicy;
    } = {},
  ): Promise<void> {
    if (!this.#threadId) throw new Error("no thread open");
    // The first message to a chat that was only read is what loads it.
    if (this.#loadedThreadId !== this.#threadId) {
      // A bot's job goes back in here, and this is the only place it can.
      // `thread/start` took it once and resuming never sent it again, so
      // reopening a bot's chat produced an agent holding the transcript with
      // no idea it was the one that reconciles the ledger every morning.
      await this.request("thread/resume", {
        threadId: this.#threadId,
        ...(this.#standingInstructions
          ? { developerInstructions: this.#standingInstructions }
          : {}),
      });
      this.#loadedThreadId = this.#threadId;
    }
    const attachments = options.attachments ?? [];
    const input: Record<string, unknown>[] = [];
    for (const attachment of attachments) {
      if (attachment.kind === "image") {
        input.push({ type: "image", url: attachment.dataUrl });
      } else if (attachment.kind === "skill") {
        // A skill is invoked by name *and* path: the server resolves it from
        // disk, so a name alone is not enough to find it.
        input.push({ type: "skill", name: attachment.name, path: attachment.path });
      }
    }

    // Files are named in the text rather than sent as `mention` inputs: the
    // server resolves those against connectors and skills, so a file path it
    // does not recognise is dropped without a word — the agent never learns the
    // file exists. Naming it lets the agent read it with the tools it has.
    const paths = attachments
      .filter((attachment) => attachment.kind === "file")
      .map((attachment) => `- ${attachment.path}`);
    const body = paths.length > 0 ? `${text}\n\nAttached files:\n${paths.join("\n")}` : text;

    // The images go first so they read as context for the text.
    input.push({ type: "text", text: body });

    await this.request("turn/start", {
      threadId: this.#threadId,
      input,
      ...(options.effort ? { effort: options.effort } : {}),
      ...(options.summary ? { summary: options.summary } : {}),
      ...(options.model ? { model: options.model } : {}),
      // Sent every turn for the same reason the model is: fixed at
      // `thread/start`, changing it mid-conversation would do nothing, and a
      // control that does nothing is worse than no control.
      ...(options.approvalPolicy ? { approvalPolicy: options.approvalPolicy } : {}),
    });
  }

  /**
   * Answer an approval request the agent is waiting on.
   *
   * The wire values are `accept`/`decline` (the server's
   * `CommandExecutionApprovalDecision`, serialised camelCase). Sending anything
   * else is not rejected — the command simply never runs — so this maps from
   * the UI's wording rather than passing a string straight through.
   */
  respondToApproval(id: RequestId, decision: "approved" | "denied"): void {
    const wire = decision === "approved" ? "accept" : "decline";
    this.#socket?.send(JSON.stringify({ id, result: { decision: wire } }));
  }

  /** Cancel the turn currently running, if any. */
  async interrupt(turnId = "0"): Promise<void> {
    if (!this.#threadId) return;
    await this.request("turn/interrupt", { threadId: this.#threadId, turnId });
  }

  async listModels(): Promise<ModelOption[]> {
    const result = (await this.request("model/list", {})) as { data?: unknown[] };
    return (result.data ?? []).map((raw) => {
      const entry = raw as Record<string, unknown>;
      const efforts = Array.isArray(entry.supportedReasoningEfforts)
        ? entry.supportedReasoningEfforts
            .map((e) => (e as Record<string, unknown>).reasoningEffort)
            .filter((e): e is string => typeof e === "string")
        : [];
      return {
        id: String(entry.id ?? entry.model ?? ""),
        model: String(entry.model ?? entry.id ?? ""),
        displayName: String(entry.displayName ?? entry.model ?? ""),
        description: String(entry.description ?? ""),
        reasoningEfforts: efforts,
      };
    });
  }

  async listThreads(): Promise<ThreadSummary[]> {
    const result = (await this.request("thread/list", {
      // Omitting this filters to the *current session's* provider, so past
      // chats vanish the moment the user switches model. An empty array means
      // "every provider", which is what a list of your own chats should be.
      modelProviders: [],
      // Omitting this defaults to "interactive" sources — CLI and VS Code
      // only — so a chat started here, whose source is `appServer`, would
      // never appear in this app's own list. The sub-agent kinds are left out
      // on purpose: internal machinery, not conversations the user had.
      sourceKinds: ["appServer", "cli", "vscode"],
    })) as { data?: unknown[] };
    return (result.data ?? []).map((raw) => {
      const entry = raw as Record<string, unknown>;
      return {
        id: String(entry.id ?? ""),
        preview: String(entry.preview ?? "(no messages)"),
        updatedAt: Number(entry.updatedAt ?? 0),
        name: typeof entry.name === "string" ? entry.name : undefined,
      };
    });
  }

  /**
   * Reopen a stored thread and return what was said in it.
   *
   * `thread/resume` replays nothing, so a UI that only resumed showed an empty
   * transcript — the conversation looked lost. The history comes from
   * `thread/read`, whose stored items use the same shapes as the live stream.
   */
  async resumeThread(
    id: string,
    options: {
      /** A bot's job, re-sent when this thread is loaded. */
      instructions?: string;
    } = {},
  ): Promise<ThreadItem[]> {
    this.#threadId = id;
    this.#standingInstructions = options.instructions?.trim() || null;
    this.#streaming.clear();
    this.#shownAs.clear();
    this.#thought = null;
    this.#lastThought = null;
    this.#writing = null;
    this.#turnBegan = null;
    this.#waitShown = false;
    this.#compactingSince = null;

    /*
     * Opening a chat reads it; it does not load it into the agent.
     *
     * Reading takes about fifty milliseconds. Resuming loads the thread and
     * starts its MCP servers, which measured 2.3 seconds against one that
     * fails to authenticate — and the app server answers these in the order
     * they arrive, so sending both at once only queues the fast one behind the
     * slow one.
     *
     * Most chats are opened to be read. The cost is paid by `send`, on the
     * first message to a chat that has not been loaded yet, which is the point
     * at which it buys something.
     */
    const result = (await this.request("thread/read", {
      threadId: id,
      includeTurns: true,
    })) as {
      thread?: {
        turns?: { items?: unknown[]; totalMs?: number | null }[];
        tokenUsage?: {
          total?: Record<string, number>;
          modelContextWindow?: number | null;
        };
      };
    };

    // What it cost, as recorded. Without this a reopened conversation that had
    // spent a hundred thousand tokens reported nothing.
    const recorded = result.thread?.tokenUsage;
    if (recorded?.total) {
      this.#events.onTokenUsage?.({
        total: recorded.total.totalTokens ?? 0,
        last: 0,
        input: recorded.total.inputTokens ?? 0,
        output: recorded.total.outputTokens ?? 0,
        contextWindow: recorded.modelContextWindow ?? null,
      });
    }

    /*
     * What each reopened turn took, put back where the live view shows it.
     *
     * The total only. A live turn also shows the wait before the model said
     * anything, which a rollout cannot recover: a thought is written when it
     * finishes, so the gap from the request to that record holds the wait and
     * the thinking together. Showing it as a wait would print the same span
     * twice — once as the wait, again as the thought that contains it.
     */
    return (result.thread?.turns ?? []).flatMap((turn, at) => {
      const items = (turn.items ?? []).flatMap((raw) => {
        const item = toThreadItem(raw as Record<string, unknown>);
        return item ? [item] : [];
      });

      if (typeof turn.totalMs === "number" && items.length > 0) {
        items.push({ id: `total:${at}`, kind: "total", text: "", durationMs: turn.totalMs });
      }

      return items;
    });
  }

  /** Give a chat a name, so the list is readable later. */
  async renameThread(id: string, name: string): Promise<void> {
    await this.request("thread/name/set", { threadId: id, name });
  }

  /**
   * Archive a chat, removing it from the list.
   *
   * There is no delete: the transcript stays on disk, which is the honest
   * behaviour for a local agent — a button that claimed to delete while
   * leaving the file behind would be worse than one that says "archive".
   */
  async archiveThread(id: string): Promise<void> {
    await this.request("thread/archive", { threadId: id });
  }

  async listSkills(cwd: string): Promise<SkillSummary[]> {
    const result = (await this.request("skills/list", { cwds: [cwd] })) as {
      data?: { skills?: unknown[] }[];
    };
    return (result.data ?? []).flatMap((group) =>
      (group.skills ?? []).map((raw) => {
        const entry = raw as Record<string, unknown>;
        return {
          name: String(entry.name ?? ""),
          description: String(entry.description ?? ""),
          path: String(entry.path ?? ""),
          enabled: entry.enabled !== false,
        };
      }),
    );
  }

  /**
   * Turn a skill on or off.
   *
   * By path, not by name: two directories can offer a skill with the same
   * name, and the one being switched is the one on disk.
   */
  async setSkillEnabled(path: string, enabled: boolean): Promise<void> {
    await this.request("skills/config/write", { path, enabled });
  }

  async listConnectors(): Promise<ConnectorSummary[]> {
    const result = (await this.request("mcpServerStatus/list", {})) as { data?: unknown[] };
    return (result.data ?? []).map((raw) => {
      const entry = raw as Record<string, unknown>;
      const tools = Array.isArray(entry.tools)
        ? entry.tools.map((tool) => {
            const named = tool as Record<string, unknown>;
            return String(named.name ?? named.title ?? tool);
          })
        : [];
      return {
        name: String(entry.name ?? entry.server ?? "unknown"),
        toolCount: tools.length,
        status: String(entry.authStatus ?? entry.status ?? "configured"),
        tools,
      };
    });
  }

  async listTasks(): Promise<ScheduledTask[]> {
    const result = (await this.request("schedule/list", {})) as { data?: unknown[] };
    return (result.data ?? []) as ScheduledTask[];
  }

  async createTask(task: {
    name: string;
    prompt: string;
    intervalSeconds: number;
    cwd: string;
  }): Promise<ScheduledTask> {
    return (await this.request("schedule/create", task)) as ScheduledTask;
  }

  async deleteTask(id: string): Promise<void> {
    await this.request("schedule/delete", { id });
  }

  /** Run a task now, without waiting for its next turn. */
  async runTaskNow(id: string): Promise<void> {
    await this.request("schedule/runNow", { id });
  }

  async setTaskEnabled(id: string, enabled: boolean): Promise<void> {
    await this.request("schedule/setEnabled", { id, enabled });
  }

  async listProjects(): Promise<Project[]> {
    const result = (await this.request("project/list", {})) as { data?: unknown[] };
    return (result.data ?? []) as Project[];
  }

  /** What is at the top level of a project's directory. */
  async projectFiles(id: string): Promise<ProjectFile[]> {
    const result = (await this.request("project/files", { id })) as { data?: unknown[] };
    return (result.data ?? []) as ProjectFile[];
  }

  /** Where new projects go by default, and whether that place exists yet. */
  async projectsRoot(): Promise<{ root: string; exists: boolean }> {
    return (await this.request("project/root", {})) as { root: string; exists: boolean };
  }

  async createProject(project: {
    name: string;
    cwd: string;
    instructions: string;
    description?: string;
    /** Make the folder if it is not there. Only its last component. */
    createDirectory?: boolean;
  }): Promise<Project> {
    return (await this.request("project/create", project)) as Project;
  }

  /** Save one or more fields; omitted fields keep their stored value. */
  async updateProject(
    id: string,
    changes: {
      name?: string;
      cwd?: string;
      instructions?: string;
      description?: string;
      pinned?: boolean;
    },
  ): Promise<Project> {
    return (await this.request("project/update", { id, ...changes })) as Project;
  }

  async deleteProject(id: string): Promise<void> {
    await this.request("project/delete", { id });
  }

  /** Record that a thread belongs to a project. Safe to call repeatedly. */
  async attachThread(id: string, threadId: string): Promise<void> {
    await this.request("project/attachThread", { id, threadId });
  }

  /**
   * List remembered facts.
   *
   * `projectId` narrows the list to what applies to that project — the global
   * facts plus its own. `instructions` is the rendered block to prepend to a
   * thread, returned by the server so the client does not have to reproduce
   * the formatting the agent expects.
   */
  async listMemories(
    options: { projectId?: string | null; applicableOnly?: boolean } = {},
  ): Promise<{ memories: Memory[]; instructions: string }> {
    const result = (await this.request("memory/list", {
      ...(options.applicableOnly ? { applicable: true } : {}),
      ...(options.projectId ? { projectId: options.projectId } : {}),
    })) as { data?: unknown[]; instructions?: string };
    return {
      memories: (result.data ?? []) as Memory[],
      instructions: typeof result.instructions === "string" ? result.instructions : "",
    };
  }

  async createMemory(text: string, projectId?: string | null): Promise<Memory> {
    return (await this.request("memory/create", {
      text,
      ...(projectId ? { projectId } : {}),
    })) as Memory;
  }

  async updateMemory(id: string, text: string): Promise<Memory> {
    return (await this.request("memory/update", { id, text })) as Memory;
  }

  async deleteMemory(id: string): Promise<void> {
    await this.request("memory/delete", { id });
  }

  /**
   * List background runs.
   *
   * `activeOnly` narrows to what has not finished, which is what the Active
   * list on the landing screen shows.
   */
  async listRuns(options: { activeOnly?: boolean; limit?: number } = {}): Promise<Run[]> {
    const result = (await this.request("dispatch/list", {
      ...(options.activeOnly ? { activeOnly: true } : {}),
      ...(options.limit ? { limit: options.limit } : {}),
    })) as { data?: unknown[] };
    return (result.data ?? []) as Run[];
  }

  async dispatchRun(run: {
    prompt: string;
    cwd: string;
    title?: string;
    model?: string;
    source?: RunSource;
  }): Promise<Run> {
    return (await this.request("dispatch/create", run)) as Run;
  }

  /** Stop a run being started, or mark a running one as abandoned. */
  async cancelRun(id: string): Promise<void> {
    await this.request("dispatch/cancel", { id });
  }

  async deleteRun(id: string): Promise<void> {
    await this.request("dispatch/delete", { id });
  }

  /** Forget every finished run. Returns how many were cleared. */
  /**
   * Where a conversation starts when nobody has said where.
   *
   * Asked of the gateway rather than defaulting to `"."` here, because the
   * answer is a boundary and not a convenience: the working directory is what
   * `workspace-write` makes writable, and `"."` is wherever the gateway
   * happened to be started from. The desktop shell asks its own process the
   * same question and must get the same answer.
   */
  async defaultWorkspace(): Promise<string> {
    try {
      const result = (await this.request("workspace/default", {})) as { path?: string };
      return result.path ?? ".";
    } catch {
      // An older gateway does not know the method. Falling back to the home
      // directory is what this exists to avoid, so it falls back to nothing
      // in particular instead.
      return ".";
    }
  }

  /** Every bot, or one department's roster. */
  async listBots(department?: string): Promise<Bot[]> {
    const result = (await this.request(
      "bot/list",
      department ? { department } : {},
    )) as { data?: unknown[] };
    return (result.data ?? []) as Bot[];
  }

  async createBot(bot: { department: string; name: string; job?: string }): Promise<Bot> {
    return (await this.request("bot/create", bot)) as Bot;
  }

  async updateBot(
    id: string,
    changes: { name?: string; job?: string; threadId?: string; status?: BotStatus },
  ): Promise<Bot> {
    return (await this.request("bot/update", { id, ...changes })) as Bot;
  }

  async deleteBot(id: string): Promise<boolean> {
    const result = (await this.request("bot/delete", { id })) as { removed?: boolean };
    return result.removed === true;
  }

  /**
   * Who an address points at, and whether it may be written to from here.
   *
   * Both in one answer, because a caller that resolved a bot and then messaged
   * it could skip the department's policy — and the policy is the only thing
   * keeping one department's bots from driving another's.
   */
  async resolveBot(
    address: string,
    from: string,
  ): Promise<{ found: boolean; allowed?: boolean; bot?: Bot }> {
    return (await this.request("bot/resolve", { address, from })) as {
      found: boolean;
      allowed?: boolean;
      bot?: Bot;
    };
  }

  async clearRuns(): Promise<number> {
    const result = (await this.request("dispatch/clear", {})) as { cleared?: number };
    return result.cleared ?? 0;
  }

  /** Read the connectors configured on this machine. */
  async listConnectorConfigs(): Promise<ConnectorConfig[]> {
    const result = (await this.request("connector/list", {})) as { data?: unknown[] };
    return (result.data ?? []) as ConnectorConfig[];
  }

  /** Connectors offered by name, with how each is started. */
  async connectorCatalog(): Promise<ConnectorOffer[]> {
    const result = (await this.request("connector/catalog", {})) as { data?: unknown[] };
    return (result.data ?? []) as ConnectorOffer[];
  }

  async addConnector(connector: {
    name: string;
    transport: ConnectorOffer["transport"];
  }): Promise<ConnectorConfig> {
    return (await this.request("connector/add", connector)) as ConnectorConfig;
  }

  /**
   * Turn a connector on or off.
   *
   * Servers start with the session, so the change takes effect on the next
   * chat rather than this one.
   */
  async setConnectorEnabled(name: string, enabled: boolean): Promise<void> {
    await this.request("connector/setEnabled", { name, enabled });
  }

  async removeConnector(name: string): Promise<void> {
    await this.request("connector/remove", { name });
  }

  async listPlugins(): Promise<InstalledPlugin[]> {
    const result = (await this.request("plugin/list", {})) as { data?: unknown[] };
    return (result.data ?? []) as InstalledPlugin[];
  }

  async pluginCatalog(): Promise<PluginOffer[]> {
    const result = (await this.request("plugin/catalog", {})) as { data?: unknown[] };
    return (result.data ?? []) as PluginOffer[];
  }

  /**
   * Install a skill by cloning it.
   *
   * `loadable` says whether what arrived is itself a skill: a repository *of*
   * skills is not one, and the agent will not pick it up directly.
   */
  async installPlugin(name: string, source: string): Promise<{ name: string; loadable: boolean }> {
    return (await this.request("plugin/install", { name, source })) as {
      name: string;
      loadable: boolean;
    };
  }

  async removePlugin(name: string): Promise<void> {
    await this.request("plugin/remove", { name });
  }

  /**
   * Write a skill from what this chat just did.
   *
   * The transcript is raw material, not the product: what is stored is the
   * summary the user approved, not every message that led to it.
   */
  async recordSkill(skill: {
    name: string;
    description: string;
    body: string;
  }): Promise<{ name: string; path: string }> {
    return (await this.request("plugin/record", skill)) as { name: string; path: string };
  }

  /** Clone a repository into a directory, to work on rather than to load. */
  async cloneRepository(url: string, into: string): Promise<{ name: string; path: string }> {
    return (await this.request("plugin/clone", { url, into })) as { name: string; path: string };
  }

  /** The runtimes this build knows, and what each can be asked to do. */
  async listRuntimes(): Promise<RuntimeInfo[]> {
    const result = (await this.request("runtime/list", {})) as { data?: unknown[] };
    return (result.data ?? []) as RuntimeInfo[];
  }

  /**
   * Look for runtimes on this machine.
   *
   * Probed together rather than one after another: four timeouts in sequence
   * on a machine with none is long enough to look broken.
   */
  async discoverRuntimes(): Promise<DiscoveredRuntime[]> {
    const result = (await this.request("runtime/discover", {})) as { data?: unknown[] };
    return (result.data ?? []) as DiscoveredRuntime[];
  }

  /** Ask an address what is there. */
  async probeRuntime(baseUrl: string): Promise<RuntimeProbe> {
    return (await this.request("runtime/probe", { baseUrl })) as RuntimeProbe;
  }

  async runtimeModels(baseUrl: string): Promise<InstalledModel[]> {
    const result = (await this.request("runtime/models", { baseUrl })) as { data?: unknown[] };
    return (result.data ?? []) as InstalledModel[];
  }

  async modelCapabilities(baseUrl: string, model: string): Promise<ModelCapabilities> {
    return (await this.request("runtime/show", { baseUrl, model })) as ModelCapabilities;
  }

  /**
   * Start installing a model.
   *
   * Returns as soon as it has begun; progress arrives as `onPullProgress`
   * until `done` or `error`. A model is gigabytes, so waiting for the reply
   * would look like the app had frozen.
   */
  async pullModel(baseUrl: string, model: string): Promise<void> {
    await this.request("runtime/pull", { baseUrl, model });
  }

  async deleteModel(baseUrl: string, model: string): Promise<void> {
    await this.request("runtime/delete", { baseUrl, model });
  }

  /**
   * Make an installed model selectable in the picker.
   *
   * Installing puts a file on a machine; choosing it needs a provider and a
   * `[[models]]` entry as well. Without this a one-click install is one click
   * and then a text editor.
   */
  /**
   * Which of a machine's models the chat picker already offers.
   *
   * Installing puts a file on a machine; the picker offers what config.toml
   * names. Showing seven installed while the picker holds two, with nothing
   * saying why, reads as a broken picker.
   */
  async registeredModels(baseUrl: string): Promise<string[]> {
    const result = (await this.request("runtime/registered", { baseUrl })) as {
      data?: unknown[];
    };
    return (result.data ?? []).map(String);
  }

  async registerModel(baseUrl: string, model: string): Promise<{ added: boolean }> {
    return (await this.request("runtime/register", { baseUrl, model })) as { added: boolean };
  }

  /**
   * Reload the session so a configuration change takes effect.
   *
   * The agent reads `config.toml` when its process starts, so a model
   * registered a moment ago is on disk but not in the picker. Reconnecting is
   * what makes it appear.
   */
  async reload(url: string, options: { cwd: string; model?: string }): Promise<void> {
    this.close();
    await this.connect(url, options);
  }

  async listServers(): Promise<ServerEntry[]> {
    const result = (await this.request("server/list", {})) as { data?: unknown[] };
    return (result.data ?? []) as ServerEntry[];
  }

  /** Hosts the user's own `~/.ssh/config` already names. */
  async sshAliases(): Promise<SshAlias[]> {
    const result = (await this.request("server/aliases", {})) as { data?: unknown[] };
    return (result.data ?? []) as SshAlias[];
  }

  async addServer(server: {
    name: string;
    baseUrl: string;
    runtime?: string;
    sshAlias?: string;
  }): Promise<ServerEntry> {
    return (await this.request("server/add", server)) as ServerEntry;
  }

  async removeServer(id: string): Promise<void> {
    await this.request("server/remove", { id });
  }

  /**
   * Look at a server closely enough to say what is wrong.
   *
   * HTTP alone cannot tell a runtime that is down from a network that is out,
   * nor see a service that has been restarting in a loop. With a shell it can.
   */
  async diagnoseServer(id: string): Promise<Diagnosis> {
    return (await this.request("server/diagnose", { id })) as Diagnosis;
  }

  /** Models from the curated library, optionally filtered and fit-checked. */
  async modelCatalog(options: { query?: string; memoryGb?: number } = {}): Promise<Offer[]> {
    const result = (await this.request("hub/catalog", options)) as { data?: unknown[] };
    return (result.data ?? []) as Offer[];
  }

  /**
   * Add or replace one of your own catalogue entries.
   *
   * A bundled entry is replaced by adding one with the same tag rather than
   * edited in place, so a build's own catalogue stays whole and a bad edit is
   * undone by removing the override.
   */
  async saveCatalogEntry(entry: {
    tag: string;
    name?: string;
    note: string;
    sizeGb?: number;
    needsGb?: number;
    tools?: boolean;
    context?: number;
  }): Promise<void> {
    await this.request("hub/upsert", entry);
  }

  async removeCatalogEntry(tag: string): Promise<void> {
    await this.request("hub/remove", { tag });
  }

  /**
   * The most-downloaded models, for browsing without knowing a name.
   *
   * Served from a cache the gateway warms at startup, so this returns at once
   * even on a slow link. `stale` says the figures are old and being refreshed,
   * which is shown rather than hidden.
   */
  async popularModels(
    options: { offset?: number; limit?: number } = {},
  ): Promise<{ models: Offer[]; total: number; stale: boolean; fetchedAt: number }> {
    const result = (await this.request("hub/popular", options)) as {
      data?: unknown[];
      total?: number;
      stale?: boolean;
      fetchedAt?: number;
    };
    return {
      models: (result.data ?? []) as Offer[],
      total: result.total ?? 0,
      stale: result.stale ?? false,
      fetchedAt: result.fetchedAt ?? 0,
    };
  }

  /** Search a hub for installable models. */
  async searchModels(
    query: string,
    source: "huggingface" | "modelscope" = "huggingface",
  ): Promise<{ results: Offer[]; hint?: string }> {
    const result = (await this.request("hub/search", { query, source })) as {
      data?: unknown[];
      hint?: string;
    };
    return { results: (result.data ?? []) as Offer[], hint: result.hint };
  }

  /**
   * Every model on every known machine, in one list.
   *
   * Asked of all machines at once rather than one at a time: models live
   * across several, and having to switch machines to see what you own is the
   * question this answers.
   *
   * `onUpdate` is called with everything known so far, each time more is
   * known: when a machine names its models, and again as what each model can
   * do arrives. Waiting for all of it turned a list that a local runtime
   * answers in milliseconds into a five-second one, because a machine across
   * the internet takes a second and a half to list and 2.5 seconds per model
   * to describe.
   *
   * The promise still resolves only once every machine has listed, so a
   * caller that just wants the answer can ignore the callback.
   */
  async allInstalledModels(
    onUpdate?: (rows: ModelLocation[]) => void,
  ): Promise<ModelLocation[]> {
    const [saved, here] = await Promise.all([
      this.listServers().catch(() => [] as ServerEntry[]),
      this.discoverRuntimes().catch(() => [] as DiscoveredRuntime[]),
    ]);

    const machines = [
      ...saved.map((server) => ({ label: server.name, baseUrl: server.baseUrl })),
      ...here
        .filter((runtime) => !saved.some((server) => server.baseUrl === runtime.baseUrl))
        .map((runtime) => ({
          label: `${runtime.name} on this machine`,
          baseUrl: runtime.baseUrl,
        })),
    ];

    const found = new Map<string, ModelLocation>();
    const sorted = () =>
      [...found.values()].sort((a, b) => a.model.name.localeCompare(b.model.name));
    const emit = () => onUpdate?.(sorted());

    await Promise.all(
      machines.map(async (machine) => {
        // One unreachable machine must not empty the list; it simply
        // contributes nothing.
        const models = await this.runtimeModels(machine.baseUrl).catch(() => []);
        for (const model of models) {
          found.set(`${machine.baseUrl}:${model.name}`, {
            server: machine.label,
            baseUrl: machine.baseUrl,
            manageable: true,
            model,
          });
        }
        // This machine's models appear now rather than when the slowest one
        // answers: a runtime on this computer replies in milliseconds and one
        // across the internet in a second and a half.
        emit();

        void Promise.all(
          models.map(async (model) => {
            const capabilities = await this.modelCapabilities(
              machine.baseUrl,
              model.name,
            ).catch(() => undefined);
            if (!capabilities) return;
            const key = `${machine.baseUrl}:${model.name}`;
            const row = found.get(key);
            if (!row) return;
            found.set(key, { ...row, capabilities });
            emit();
          }),
        );
      }),
    );

    return sorted();
  }

  /**
   * Machines a model could be installed to.
   *
   * Deliberately does not read memory. Doing so meant an SSH round trip per
   * machine before the dialog could show anything, which took six seconds
   * against one remote server — six seconds of a dialog that says "looking at
   * your machines" and offers nothing. Memory is read by `machineMemoryGb`
   * for the machine actually chosen, which is the only one it matters for.
   */
  async installTargets(): Promise<InstallTarget[]> {
    const [saved, here] = await Promise.all([
      this.listServers().catch(() => [] as ServerEntry[]),
      this.discoverRuntimes().catch(() => [] as DiscoveredRuntime[]),
    ]);

    const machines = [
      ...saved.map((server) => ({ label: server.name, baseUrl: server.baseUrl, id: server.id })),
      ...here
        .filter((runtime) => !saved.some((server) => server.baseUrl === runtime.baseUrl))
        .map((runtime) => ({
          label: `${runtime.name} on this machine`,
          baseUrl: runtime.baseUrl,
          id: undefined as string | undefined,
        })),
    ];

    return Promise.all(
      machines.map(async (machine) => {
        const [probe, installed] = await Promise.all([
          this.probeRuntime(machine.baseUrl).catch(() => ({ reachable: false }) as RuntimeProbe),
          this.runtimeModels(machine.baseUrl).catch(() => []),
        ]);

        return {
          label: machine.label,
          baseUrl: machine.baseUrl,
          reachable: probe.reachable,
          // Read separately, and only for the machine chosen.
          memoryGb: null,
          installed: installed.map((model) => model.name),
        };
      }),
    );
  }

  /**
   * How much memory a machine has for models, or null when it cannot be read.
   *
   * Only knowable where a shell can reach it, which needs a saved server with
   * an SSH alias. Guessing would be worse than leaving the fit unstated: the
   * figure decides which quantisation gets recommended.
   */
  async machineMemoryGb(baseUrl: string): Promise<number | null> {
    const saved = await this.listServers().catch(() => [] as ServerEntry[]);
    const server = saved.find((entry) => entry.baseUrl === baseUrl);
    if (!server?.sshAlias) return null;

    const report = await this.diagnoseServer(server.id).catch(() => null);
    const match = /(\d+)\s*MiB/.exec(report?.shell?.gpu ?? "");
    return match ? Math.round(Number(match[1]) / 1024) : null;
  }

  /** The quantisations a Hugging Face repository offers, with real sizes. */
  async modelVariants(
    repo: string,
    memoryGb?: number,
  ): Promise<{ variants: ModelVariant[]; recommended: string | null }> {
    const result = (await this.request("hub/variants", {
      repo,
      ...(memoryGb ? { memoryGb } : {}),
    })) as { data?: unknown[]; recommended?: string };
    return {
      variants: (result.data ?? []) as ModelVariant[],
      recommended: result.recommended ?? null,
    };
  }

  /** Read the effective config after layering. */
  async readConfig(): Promise<Record<string, unknown>> {
    const result = (await this.request("config/read", {})) as Record<string, unknown>;
    return result;
  }

  /**
   * Which API keys are set.
   *
   * Names and whether each has a value — never the values themselves. A key on
   * screen is a key in a screenshot.
   *
   * `names` says which variables the caller cares about, on top of whatever is
   * already stored: the `env_key` of each configured provider, or the ones a
   * connector declares. Without it the server would have to guess, and
   * guessing by name listed a shell's unrelated credentials.
   */
  async listSecrets(names: string[] = []): Promise<SecretStatus[]> {
    const result = (await this.request("secret/list", { names })) as {
      secrets?: SecretStatus[];
    };
    return result.secrets ?? [];
  }

  /** Set an API key, or clear it by passing `null`. */
  async writeSecret(name: string, value: string | null): Promise<void> {
    await this.request("secret/write", { name, ...(value === null ? {} : { value }) });
  }

  /**
   * Write one setting into `config.toml`.
   *
   * `keyPath` is dotted — `model`, `approval_policy` — and the server keeps the
   * file's comments and formatting as it edits.
   */
  async writeConfigValue(keyPath: string, value: unknown): Promise<void> {
    await this.request("config/value/write", {
      keyPath,
      value,
      mergeStrategy: "replace",
    });
  }

  close(): void {
    this.#socket?.close();
  }
}
