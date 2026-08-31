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

/** A turn item as surfaced to the UI. */
export interface ThreadItem {
  id: string;
  kind: "user" | "agent" | "command" | "reasoning" | "other";
  text: string;
  /** Present for command items once the command has finished. */
  exitCode?: number;
}

export interface ClientEvents {
  onItem?: (item: ThreadItem) => void;
  onTurnComplete?: () => void;
  onError?: (message: string) => void;
  /** The agent is asking permission to run something. */
  onApprovalRequest?: (request: ApprovalRequest) => void;
  onStatus?: (status: ConnectionStatus) => void;
}

export interface ApprovalRequest {
  /** The request id to answer with. */
  id: RequestId;
  command: string;
  cwd?: string;
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
  enabled: boolean;
}

/** A workspace: a directory, standing instructions, and its threads. */
export interface Project {
  id: string;
  name: string;
  cwd: string;
  instructions: string;
  createdAt: number;
  threadIds: string[];
}

/** A configured MCP server and whether it is usable. */
export interface ConnectorSummary {
  name: string;
  toolCount: number;
  status: string;
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

function classify(item: Record<string, unknown>): ThreadItem["kind"] {
  const type = String(item.type ?? item.itemType ?? "");
  if (type.includes("agentMessage") || type.includes("agent_message")) return "agent";
  if (type.includes("userMessage") || type.includes("user_message")) return "user";
  if (type.includes("command") || type.includes("exec")) return "command";
  if (type.includes("reasoning")) return "reasoning";
  return "other";
}

export class OpenCliClient {
  #socket: WebSocket | null = null;
  #nextId = 1;
  #pending = new Map<RequestId, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();
  #events: ClientEvents;
  #threadId: string | null = null;

  constructor(events: ClientEvents = {}) {
    this.#events = events;
  }

  get threadId(): string | null {
    return this.#threadId;
  }

  /** Connect, complete the handshake, and open a thread. */
  async connect(
    url: string,
    options: { cwd: string; model?: string; instructions?: string },
  ): Promise<void> {
    this.#events.onStatus?.("connecting");
    await this.#open(url);

    await this.request("initialize", {
      clientInfo: { name: "opencli_web", title: "OpenCLI Web", version: "0.1.0" },
    });
    this.notify("initialized");

    const started = (await this.request("thread/start", {
      cwd: options.cwd,
      ...(options.model ? { model: options.model } : {}),
      // `developerInstructions` appends a message to the context;
      // `baseInstructions` would *replace* the whole system prompt and cost the
      // agent its normal operating rules. A project adds context, so append.
      ...(options.instructions?.trim()
        ? { developerInstructions: options.instructions.trim() }
        : {}),
      // Approvals are surfaced in the UI rather than auto-granted; the agent
      // runs on the machine hosting the gateway.
      approvalPolicy: "untrusted",
      sandbox: "workspace-write",
    })) as { thread?: { id?: string }; threadId?: string };

    this.#threadId = started.thread?.id ?? started.threadId ?? null;
    if (!this.#threadId) throw new Error("server did not return a thread id");
    this.#events.onStatus?.("ready");
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
        this.#events.onApprovalRequest?.({
          id: message.id,
          command:
            (typeof params.command === "string" ? params.command : textOf(params.command)) ||
            "(unknown command)",
          cwd: typeof params.cwd === "string" ? params.cwd : undefined,
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
    // Only `item/completed` is rendered. `item/started` carries the same item
    // moments earlier — for a user message with identical content, and for an
    // agent message with empty text *and a different id*, so it can be neither
    // deduplicated by id nor shown. Waiting for completion is what actually
    // yields one correct entry per item.
    if (method === "item/completed") {
      const item = (payload.item ?? payload) as Record<string, unknown>;
      const text = textOf(item);
      if (!text) return;
      this.#events.onItem?.({
        id: String(item.id ?? crypto.randomUUID()),
        kind: classify(item),
        text,
        exitCode: typeof item.exitCode === "number" ? item.exitCode : undefined,
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

  /** Send a user message and begin a turn. */
  async send(text: string): Promise<void> {
    if (!this.#threadId) throw new Error("no thread open");
    await this.request("turn/start", {
      threadId: this.#threadId,
      input: [{ type: "text", text }],
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
    const result = (await this.request("thread/list", {})) as { data?: unknown[] };
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

  /** Reopen a stored thread so later turns append to it. */
  async resumeThread(id: string): Promise<void> {
    await this.request("thread/resume", { threadId: id });
    this.#threadId = id;
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

  async createProject(project: {
    name: string;
    cwd: string;
    instructions: string;
  }): Promise<Project> {
    return (await this.request("project/create", project)) as Project;
  }

  /** Save one or more fields; omitted fields keep their stored value. */
  async updateProject(
    id: string,
    changes: { name?: string; cwd?: string; instructions?: string },
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

  /** Read the effective config after layering. */
  async readConfig(): Promise<Record<string, unknown>> {
    const result = (await this.request("config/read", {})) as Record<string, unknown>;
    return result;
  }

  close(): void {
    this.#socket?.close();
  }
}
