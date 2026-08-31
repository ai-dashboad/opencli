import { beforeEach, describe, expect, it, vi } from "vitest";
import { OpenCliClient, type ApprovalRequest, type ThreadItem } from "./protocol";

/**
 * A stand-in for the browser's WebSocket that lets a test play the server.
 *
 * The payloads below are the shapes the app server really sends — captured from
 * a live session and cross-checked against the Rust protocol types. Testing
 * against invented shapes would only prove the client agrees with itself.
 */
class FakeSocket {
  static last: FakeSocket;
  sent: string[] = [];
  onopen: (() => void) | null = null;
  onerror: (() => void) | null = null;
  onclose: (() => void) | null = null;
  onmessage: ((event: { data: string }) => void) | null = null;

  constructor(public url: string) {
    FakeSocket.last = this;
    // Open on a later tick, as a real socket does.
    queueMicrotask(() => this.onopen?.());
  }

  send(raw: string) {
    this.sent.push(raw);
    const message = JSON.parse(raw) as { id?: number; method?: string };
    // Auto-answer the handshake so `connect()` can resolve.
    if (message.method === "initialize") {
      this.reply(message.id!, {});
    } else if (message.method === "thread/start") {
      this.reply(message.id!, { thread: { id: "thread-1" } });
    } else if (message.method === "thread/list") {
      this.reply(message.id!, {
        data: [{ id: "t-1", preview: "hello", updatedAt: 1 }],
        nextCursor: null,
      });
    } else if (message.method === "thread/resume") {
      this.reply(message.id!, {});
    } else if (message.method === "thread/read") {
      // The shape a live server returns: turns, each holding items that use
      // the same types as the streamed ones.
      this.reply(message.id!, {
        thread: {
          id: "t-1",
          turns: [
            {
              id: "turn-1",
              items: [
                { type: "userMessage", id: "i-1", content: [{ type: "text", text: "ask" }] },
                { type: "agentMessage", id: "i-2", text: "answer" },
              ],
            },
          ],
        },
      });
    } else if (message.method === "memory/list") {
      this.reply(message.id!, {
        data: [{ id: "mem-1", text: "never touch vendor/", projectId: null, createdAt: 0 }],
        instructions: "Things the user has asked you to remember:\n- never touch vendor/\n",
      });
    }
  }

  close() {
    this.onclose?.();
  }

  /** Push a server-to-client frame. */
  emit(payload: unknown) {
    this.onmessage?.({ data: JSON.stringify(payload) });
  }

  reply(id: number, result: unknown) {
    queueMicrotask(() => this.emit({ id, result }));
  }

  /** The parsed frames the client sent, for asserting on requests. */
  parsedSent(): Record<string, unknown>[] {
    return this.sent.map((raw) => JSON.parse(raw) as Record<string, unknown>);
  }
}

vi.stubGlobal("WebSocket", FakeSocket);

async function connected(events = {}) {
  const client = new OpenCliClient(events);
  await client.connect("ws://test/ws", { cwd: "/work" });
  return { client, socket: FakeSocket.last };
}

/** Let queued microtasks and promise callbacks run. */
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("connecting", () => {
  beforeEach(() => {
    FakeSocket.last = undefined as unknown as FakeSocket;
  });

  it("should take the thread id from the start response", async () => {
    const { client } = await connected();
    expect(client.threadId).toBe("thread-1");
  });

  it("should ask for per-command approval rather than letting the model decide", async () => {
    // `on-request` leaves it to the model, which rarely asks — so a UI that
    // shows an approval dialog would almost never show it.
    const { socket } = await connected();
    const start = socket
      .parsedSent()
      .find((message) => message.method === "thread/start")!;
    expect((start.params as Record<string, unknown>).approvalPolicy).toBe("untrusted");
  });

  it("should send standing instructions as developer instructions", async () => {
    // `baseInstructions` would replace the whole system prompt.
    const client = new OpenCliClient({});
    await client.connect("ws://test/ws", { cwd: "/work", instructions: "  be careful  " });
    const params = FakeSocket.last
      .parsedSent()
      .find((message) => message.method === "thread/start")!.params as Record<string, unknown>;
    expect(params.developerInstructions).toBe("be careful");
    expect(params.baseInstructions).toBeUndefined();
  });

  it("should send the chosen model so the picker is not decorative", async () => {
    const client = new OpenCliClient({});
    await client.connect("ws://test/ws", { cwd: "/work", model: "qwen2.5:3b" });
    const params = FakeSocket.last
      .parsedSent()
      .find((message) => message.method === "thread/start")!.params as Record<string, unknown>;
    expect(params.model).toBe("qwen2.5:3b");
  });

  it("should omit the model when none is chosen, leaving the default", async () => {
    const { socket } = await connected();
    const params = socket
      .parsedSent()
      .find((message) => message.method === "thread/start")!.params as Record<string, unknown>;
    expect(params).not.toHaveProperty("model");
  });

  it("should omit instructions that are only whitespace", async () => {
    const client = new OpenCliClient({});
    await client.connect("ws://test/ws", { cwd: "/work", instructions: "   " });
    const params = FakeSocket.last
      .parsedSent()
      .find((message) => message.method === "thread/start")!.params as Record<string, unknown>;
    expect(params).not.toHaveProperty("developerInstructions");
  });
});

describe("approval requests", () => {
  it("should surface a server-initiated approval request to the UI", async () => {
    const seen: ApprovalRequest[] = [];
    const { socket } = await connected({ onApprovalRequest: (r: ApprovalRequest) => seen.push(r) });

    socket.emit({
      method: "item/commandExecution/requestApproval",
      id: 0,
      params: {
        threadId: "thread-1",
        turnId: "0",
        itemId: "call_1",
        command: "touch /tmp/x",
        cwd: "/work",
      },
    });

    expect(seen).toEqual([
      { id: 0, kind: "command", command: "touch /tmp/x", cwd: "/work", reason: undefined },
    ]);
  });

  it("should show the files a write approval covers", async () => {
    // The approval names the item but does not repeat its contents; those came
    // on the earlier `item/started`. Without that lookup the user would be
    // asked to approve writes they cannot see.
    const seen: ApprovalRequest[] = [];
    const { socket } = await connected({ onApprovalRequest: (r: ApprovalRequest) => seen.push(r) });

    socket.emit({
      method: "item/started",
      params: {
        item: {
          id: "call_9",
          type: "fileChange",
          status: "inProgress",
          changes: [{ path: "/work/a.txt", kind: { type: "update" }, diff: "@@\n-old\n+new" }],
        },
      },
    });
    socket.emit({
      method: "item/fileChange/requestApproval",
      id: 3,
      params: { threadId: "thread-1", turnId: "0", itemId: "call_9", reason: "outside the workspace" },
    });

    expect(seen).toHaveLength(1);
    expect(seen[0].kind).toBe("fileChange");
    expect(seen[0].reason).toBe("outside the workspace");
    expect(seen[0].changes).toEqual([
      { path: "/work/a.txt", kind: "update", diff: "@@\n-old\n+new" },
    ]);
  });

  it("should report empty changes rather than guessing when the start was missed", async () => {
    // Showing nothing is honest; implying the write is harmless is not.
    const seen: ApprovalRequest[] = [];
    const { socket } = await connected({ onApprovalRequest: (r: ApprovalRequest) => seen.push(r) });

    socket.emit({
      method: "item/fileChange/requestApproval",
      id: 4,
      params: { itemId: "never-seen" },
    });

    expect(seen[0].changes).toEqual([]);
  });

  it("should answer with the decision values the server accepts", async () => {
    // The server's enum is accept/decline. An unparseable decision is not
    // reported as an error — the command simply never runs.
    const { client, socket } = await connected();
    client.respondToApproval(7, "approved");
    client.respondToApproval(8, "denied");

    const answers = socket.parsedSent().filter((message) => "result" in message);
    expect(answers).toEqual([
      { id: 7, result: { decision: "accept" } },
      { id: 8, result: { decision: "decline" } },
    ]);
  });

  it("should not mistake an approval request for a response to its own request", async () => {
    // Both carry a numeric id; only the request also carries a method.
    const { client, socket } = await connected();
    const pending = client.listModels();
    socket.emit({ method: "item/commandExecution/requestApproval", id: 1, params: {} });
    socket.emit({ id: FakeSocket.last.parsedSent().at(-1)!.id, result: { data: [] } });
    await expect(pending).resolves.toEqual([]);
  });
});

describe("thread items", () => {
  it("should render an agent message once, on completion", async () => {
    // `item/started` carries the same message moments earlier with empty text
    // and a *different* id, so it can be neither deduplicated nor shown.
    const items: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => items.push(item) });

    socket.emit({
      method: "item/started",
      params: { item: { id: "a", type: "agentMessage", text: "" } },
    });
    socket.emit({
      method: "item/completed",
      params: { item: { id: "b", type: "agentMessage", text: "done" } },
    });

    expect(items).toEqual([{ id: "b", kind: "agent", text: "done" }]);
  });

  it("should keep a file change, which carries no text of its own", async () => {
    // Dropping items with no text would silently hide every file the agent
    // wrote, since the payload is entirely in `changes`.
    const items: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => items.push(item) });

    socket.emit({
      method: "item/completed",
      params: {
        item: {
          id: "c",
          type: "fileChange",
          status: "completed",
          changes: [
            { path: "/work/a.txt", kind: { type: "update" }, diff: "@@\n-old\n+new" },
            { path: "/work/b.txt", kind: { type: "add" }, diff: "hello\n" },
          ],
        },
      },
    });

    expect(items).toHaveLength(1);
    expect(items[0].kind).toBe("fileChange");
    expect(items[0].changes).toEqual([
      { path: "/work/a.txt", kind: "update", diff: "@@\n-old\n+new" },
      { path: "/work/b.txt", kind: "add", diff: "hello\n" },
    ]);
    expect(items[0].text).toBe("update /work/a.txt\nadd /work/b.txt");
  });

  it("should skip a change with no path rather than showing a blank row", async () => {
    const items: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => items.push(item) });

    socket.emit({
      method: "item/completed",
      params: {
        item: {
          id: "d",
          type: "fileChange",
          changes: [{ kind: { type: "add" }, diff: "x" }, { path: "/work/ok", kind: { type: "add" }, diff: "y" }],
        },
      },
    });

    expect(items[0].changes).toEqual([{ path: "/work/ok", kind: "add", diff: "y" }]);
  });

  it("should carry the exit code of a failed command", async () => {
    const items: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => items.push(item) });

    socket.emit({
      method: "item/completed",
      params: { item: { id: "e", type: "commandExecution", text: "false", exitCode: 1 } },
    });

    expect(items[0]).toMatchObject({ kind: "command", exitCode: 1 });
  });

  it("should ignore an unfamiliar item type instead of throwing", async () => {
    const items: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => items.push(item) });

    socket.emit({ method: "item/completed", params: { item: { id: "f", type: "somethingNew" } } });
    socket.emit({ method: "totally/unknown", params: {} });
    socket.emit("not json" as unknown as object);

    expect(items).toEqual([]);
  });
});

describe("projects", () => {
  it("should send only the fields being changed on update", async () => {
    // The server leaves omitted fields alone; sending empty strings would
    // silently clear the project's instructions.
    const { client, socket } = await connected();
    void client.updateProject("proj-1", { name: "Renamed" });
    await settle();

    const update = socket.parsedSent().find((message) => message.method === "project/update")!;
    expect(update.params).toEqual({ id: "proj-1", name: "Renamed" });
  });
});

describe("memory", () => {
  it("should read the applicable facts and their rendered block", async () => {
    const { client, socket } = await connected();
    const result = await client.listMemories({ projectId: "proj-1", applicableOnly: true });

    const request = socket.parsedSent().find((message) => message.method === "memory/list")!;
    expect(request.params).toEqual({ applicable: true, projectId: "proj-1" });
    expect(result.memories).toHaveLength(1);
    expect(result.instructions).toContain("- never touch vendor/");
  });

  it("should ask for every fact when no project is given", async () => {
    // Sending `projectId: undefined` would be dropped by JSON, but sending
    // `applicable: true` without one would silently hide project facts.
    const { client, socket } = await connected();
    await client.listMemories();

    const request = socket.parsedSent().find((message) => message.method === "memory/list")!;
    expect(request.params).toEqual({});
  });

  it("should scope a new fact to a project only when one is given", async () => {
    const { client, socket } = await connected();
    void client.createMemory("global fact");
    void client.createMemory("scoped fact", "proj-1");
    await settle();

    const creates = socket
      .parsedSent()
      .filter((message) => message.method === "memory/create")
      .map((message) => message.params);
    expect(creates).toEqual([
      { text: "global fact" },
      { text: "scoped fact", projectId: "proj-1" },
    ]);
  });

  it("should combine project instructions with remembered facts in one block", async () => {
    // Both are context the agent needs; sending only one of them is the bug
    // this guards against.
    const client = new OpenCliClient({});
    await client.openSession("ws://test/ws");
    const { instructions } = await client.listMemories({ applicableOnly: true });
    await client.startThread({
      cwd: "/work",
      instructions: ["Project rule: build with just", instructions].join("\n\n"),
    });

    const params = FakeSocket.last
      .parsedSent()
      .find((message) => message.method === "thread/start")!.params as Record<string, unknown>;
    const sent = String(params.developerInstructions);
    expect(sent).toContain("Project rule: build with just");
    expect(sent).toContain("- never touch vendor/");
  });

  it("should not start a thread when only opening a session", async () => {
    // `openSession` exists so memories can be read before the thread starts;
    // starting one early would use the wrong instructions.
    const client = new OpenCliClient({});
    await client.openSession("ws://test/ws");

    expect(
      FakeSocket.last.parsedSent().some((message) => message.method === "thread/start"),
    ).toBe(false);
    expect(client.threadId).toBeNull();
  });
});

describe("threads", () => {
  it("should list chats from every provider, not just the current one", async () => {
    // Omitting the filter lists only the session's own provider, so past chats
    // vanish the moment the user switches model.
    const { client, socket } = await connected();
    await client.listThreads();

    const request = socket.parsedSent().find((message) => message.method === "thread/list")!;
    const params = request.params as Record<string, unknown>;
    expect(params.modelProviders).toEqual([]);
  });

  it("should include chats started by this app in the list", async () => {
    // The default is "interactive" sources — CLI and VS Code — which excludes
    // `appServer`, the source of every chat started here.
    const { client, socket } = await connected();
    await client.listThreads();

    const params = socket.parsedSent().find((message) => message.method === "thread/list")!
      .params as Record<string, unknown>;
    expect(params.sourceKinds).toContain("appServer");
    expect(params.sourceKinds).not.toContain("subAgent");
  });

  it("should restore the transcript when a chat is reopened", async () => {
    // `thread/resume` replays nothing on its own, so resuming alone left the
    // conversation looking lost.
    const { client } = await connected();
    const restored = await client.resumeThread("t-1");

    expect(restored).toEqual([
      { id: "i-1", kind: "user", text: "ask" },
      { id: "i-2", kind: "agent", text: "answer" },
    ]);
  });

  it("should point later turns at the reopened thread", async () => {
    const { client } = await connected();
    await client.resumeThread("t-1");
    expect(client.threadId).toBe("t-1");
  });
});
