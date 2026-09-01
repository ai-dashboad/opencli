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
  kind: "user" | "agent" | "command" | "reasoning" | "fileChange" | "other";
  text: string;
  /** Present for command items once the command has finished. */
  exitCode?: number;
  /** Present for file-change items: what was written, and the diff. */
  changes?: FileChange[];
}

export interface ClientEvents {
  onItem?: (item: ThreadItem) => void;
  onTurnComplete?: () => void;
  onError?: (message: string) => void;
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

/** A stored conversation, as listed in the sidebar. */
export interface ThreadSummary {
  id: string;
  preview: string;
  updatedAt: number;
  name?: string;
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
export interface Preferences {
  personality?: Personality;
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
  transport: { kind: "stdio" | "http"; command?: string; args?: string[]; url?: string };
}

/** A connector offered by name, with how it is started. */
export interface ConnectorOffer {
  id: string;
  name: string;
  description: string;
  transport: { kind: "stdio" | "http"; command?: string; args?: string[]; url?: string };
  note?: string;
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
  if (type.includes("reasoning")) return "reasoning";
  if (type.includes("fileChange") || type.includes("file_change")) return "fileChange";
  return "other";
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
  const text = textOf(item) || changes.map((change) => `${change.kind} ${change.path}`).join("\n");
  if (!text) return null;
  return {
    id: String(item.id ?? crypto.randomUUID()),
    kind: classify(item),
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

        if (message.method.includes("fileChange")) {
          // A file-change approval names the item but does not repeat what is
          // in it. The changes arrived earlier, on the `item/started` for the
          // same id — without that lookup the user is asked to approve writes
          // they cannot see.
          const itemId = typeof params.itemId === "string" ? params.itemId : "";
          this.#events.onApprovalRequest?.({
            id: message.id,
            kind: "fileChange",
            changes: this.#pendingChanges.get(itemId) ?? [],
            reason,
            cwd,
          });
          return;
        }

        this.#events.onApprovalRequest?.({
          id: message.id,
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

  #handleNotification(method: string, params: unknown): void {
    const payload = (params ?? {}) as Record<string, unknown>;

    if (method === "turn/completed" || method === "opencli/event/task_complete") {
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
      return;
    }
    // Only `item/completed` is rendered. `item/started` carries the same item
    // moments earlier — for a user message with identical content, and for an
    // agent message with empty text *and a different id*, so it can be neither
    // deduplicated by id nor shown. Waiting for completion is what actually
    // yields one correct entry per item.
    if (method === "item/completed") {
      const raw = (payload.item ?? payload) as Record<string, unknown>;
      if (typeof raw.id === "string") this.#pendingChanges.delete(raw.id);
      const item = toThreadItem(raw);
      if (item) this.#events.onItem?.(item);
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
    if (method.endsWith("/error") || method === "opencli/event/error") {
      this.#events.onError?.(textOf(payload) || "the agent reported an error");
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
    } = {},
  ): Promise<void> {
    if (!this.#threadId) throw new Error("no thread open");
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
  async resumeThread(id: string): Promise<ThreadItem[]> {
    await this.request("thread/resume", { threadId: id });
    this.#threadId = id;

    const result = (await this.request("thread/read", {
      threadId: id,
      includeTurns: true,
    })) as { thread?: { turns?: { items?: unknown[] }[] } };

    return (result.thread?.turns ?? []).flatMap((turn) =>
      (turn.items ?? []).flatMap((raw) => {
        const item = toThreadItem(raw as Record<string, unknown>);
        return item ? [item] : [];
      }),
    );
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

  async listConnectors(): Promise<ConnectorSummary[]> {
    const result = (await this.request("mcpServerStatus/list", {})) as { data?: unknown[] };
    return (result.data ?? []).map((raw) => {
      const entry = raw as Record<string, unknown>;
      const tools = Array.isArray(entry.tools) ? entry.tools.length : 0;
      return {
        name: String(entry.name ?? entry.server ?? "unknown"),
        toolCount: tools,
        status: String(entry.authStatus ?? entry.status ?? "configured"),
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

  close(): void {
    this.#socket?.close();
  }
}
