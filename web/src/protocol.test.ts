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

  /**
   * A test's own answers, tried before the built-in ones.
   *
   * Returning `undefined` means "not mine" and falls through, so a test only
   * has to describe the calls it cares about.
   */
  static answer:
    | ((message: { method?: string; params?: Record<string, unknown> }) => unknown | undefined)
    | null = null;

  /**
   * Reply with a JSON-RPC error rather than a result.
   *
   * Needed because a failing call and a call returning nothing are different
   * things, and a test that conflates them proves nothing about either.
   */
  static rpcError(message: string) {
    return { __rpcError: message };
  }

  send(raw: string) {
    this.sent.push(raw);
    const message = JSON.parse(raw) as {
      id?: number;
      method?: string;
      params?: Record<string, unknown>;
    };
    const answered = FakeSocket.answer?.(message) as { __rpcError?: string } | undefined;
    if (answered !== undefined) {
      if (answered.__rpcError) {
        queueMicrotask(() =>
          this.emit({ id: message.id, error: { code: -32000, message: answered.__rpcError } }),
        );
      } else {
        this.reply(message.id!, answered);
      }
      return;
    }
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
    } else if (message.method === "thread/name/set" || message.method === "thread/archive") {
      this.reply(message.id!, {});
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
      {
        id: 0,
        // Named, so it is only offered in the chat that raised it.
        threadId: "thread-1",
        kind: "command",
        command: "touch /tmp/x",
        cwd: "/work",
        reason: undefined,
      },
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

describe("an approval belongs to one conversation", () => {
  it("should say which chat is asking", async () => {
    // One agent serves every chat. Without this an approval raised in one is
    // shown in whichever happens to be on screen, and approved by someone who
    // cannot see what led to it.
    let asked: ApprovalRequest | null = null;
    const { socket } = await connected({
      onApprovalRequest: (request: ApprovalRequest) => (asked = request),
    });

    socket.emit({
      id: 99,
      method: "commandExecution/requestApproval",
      params: {
        threadId: "t-other",
        turnId: "1",
        itemId: "i-1",
        command: "rm -rf /tmp/x",
        cwd: "/work",
      },
    });

    expect(asked).not.toBeNull();
    expect(asked!.threadId).toBe("t-other");
    expect(asked!.command).toBe("rm -rf /tmp/x");
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

describe("preferences", () => {
  it("should send the personality and approval policy on a new thread", async () => {
    const client = new OpenCliClient({});
    await client.connect("ws://test/ws", {
      cwd: "/work",
      preferences: { personality: "friendly", approvalPolicy: "on-failure" },
    });

    const params = FakeSocket.last
      .parsedSent()
      .find((message) => message.method === "thread/start")!.params as Record<string, unknown>;
    expect(params.personality).toBe("friendly");
    expect(params.approvalPolicy).toBe("on-failure");
  });

  it("should keep asking for approval when no policy was chosen", async () => {
    // The default must be the cautious one: a missing preference should never
    // silently mean "run anything".
    const { socket } = await connected();
    const params = socket
      .parsedSent()
      .find((message) => message.method === "thread/start")!.params as Record<string, unknown>;
    expect(params.approvalPolicy).toBe("untrusted");
  });

  it("should send the effort with the message rather than the thread", async () => {
    // Effort is a turn option, so changing it applies to the next message
    // instead of needing a new chat.
    const { client, socket } = await connected();
    void client.send("hello", { effort: "high" });
    await settle();

    const turn = socket.parsedSent().find((message) => message.method === "turn/start")!;
    expect((turn.params as Record<string, unknown>).effort).toBe("high");
  });

  it("should omit the effort when none is chosen", async () => {
    const { client, socket } = await connected();
    void client.send("hello");
    await settle();

    const turn = socket.parsedSent().find((message) => message.method === "turn/start")!;
    expect(turn.params).not.toHaveProperty("effort");
  });

  it("should rename and archive a chat by id", async () => {
    const { client, socket } = await connected();
    void client.renameThread("t-1", "Deploy notes");
    void client.archiveThread("t-2");
    await settle();

    const sent = socket.parsedSent();
    expect(sent.find((m) => m.method === "thread/name/set")!.params).toEqual({
      threadId: "t-1",
      name: "Deploy notes",
    });
    expect(sent.find((m) => m.method === "thread/archive")!.params).toEqual({ threadId: "t-2" });
  });
});

describe("attachments", () => {
  it("should send an image before the text so it reads as context", async () => {
    const { client, socket } = await connected();
    void client.send("what is this?", {
      attachments: [{ kind: "image", name: "shot.png", dataUrl: "data:image/png;base64,AAA" }],
    });
    await settle();

    const turn = socket.parsedSent().find((message) => message.method === "turn/start")!;
    expect((turn.params as Record<string, unknown>).input).toEqual([
      { type: "image", url: "data:image/png;base64,AAA" },
      { type: "text", text: "what is this?" },
    ]);
  });

  it("should name an attached file in the text so the agent can read it", async () => {
    // Sending it as a `mention` looks right but is dropped: the server resolves
    // those against connectors and skills, so an ordinary path never reaches
    // the model and the agent never learns the file exists.
    const { client, socket } = await connected();
    void client.send("review this", {
      attachments: [{ kind: "file", name: "notes.md", path: "/work/notes.md" }],
    });
    await settle();

    const turn = socket.parsedSent().find((message) => message.method === "turn/start")!;
    expect((turn.params as Record<string, unknown>).input).toEqual([
      { type: "text", text: "review this\n\nAttached files:\n- /work/notes.md" },
    ]);
  });

  it("should invoke a skill by name and path", async () => {
    // The server resolves a skill from disk, so a name alone cannot find it.
    const { client, socket } = await connected();
    void client.send("use it", {
      attachments: [{ kind: "skill", name: "design", path: "/skills/design" }],
    });
    await settle();

    const turn = socket.parsedSent().find((message) => message.method === "turn/start")!;
    expect((turn.params as Record<string, unknown>).input).toEqual([
      { type: "skill", name: "design", path: "/skills/design" },
      { type: "text", text: "use it" },
    ]);
  });

  it("should still send a plain message with no attachments", async () => {
    const { client, socket } = await connected();
    void client.send("just text");
    await settle();

    const turn = socket.parsedSent().find((message) => message.method === "turn/start")!;
    expect((turn.params as Record<string, unknown>).input).toEqual([
      { type: "text", text: "just text" },
    ]);
  });
});

describe("starting another chat", () => {
  it("should open a second thread on the same connection", async () => {
    // A new chat is a new thread, not a new connection. Reconnecting drops the
    // socket and sends the app back to its starting screen, which reads as the
    // window reopening.
    const { client, socket } = await connected();
    const first = client.threadId;

    await client.startThread({ cwd: "/work" });

    expect(client.threadId).toBe(first === "thread-1" ? "thread-1" : first);
    expect(socket.parsedSent().filter((m) => m.method === "initialize")).toHaveLength(1);
    expect(socket.parsedSent().filter((m) => m.method === "thread/start")).toHaveLength(2);
  });
});


describe("when the agent stops to ask", () => {
  beforeEach(() => {
    // A turn is begun, not awaited to completion, so it only needs an ack.
    FakeSocket.answer = (message) => (message.method === "turn/start" ? {} : undefined);
  });

  it("should carry the mode on every turn, not just the first", async () => {
    // Sent only at thread/start, changing it mid-conversation did nothing —
    // which is the worst way for a security control to be wrong, because it
    // looks as though it took.
    const { client, socket } = await connected();
    await client.startThread({ cwd: "/work" });
    await client.send("go", { approvalPolicy: "on-failure" });
    await settle();

    const turn = socket.parsedSent().find((sent) => sent.method === "turn/start")!;
    expect((turn.params as Record<string, unknown>).approvalPolicy).toBe("on-failure");
  });

  it("should say nothing about approvals when none was chosen", async () => {
    // Omitting the field leaves the server on whatever the thread began with,
    // rather than this quietly asserting a default of its own.
    const { client, socket } = await connected();
    await client.startThread({ cwd: "/work" });
    await client.send("go");
    await settle();

    const turn = socket.parsedSent().find((sent) => sent.method === "turn/start")!;
    expect(turn.params).not.toHaveProperty("approvalPolicy");
  });
});

describe("what the agent did, not only what it said about it", () => {
  it("should show a command and what it printed", async () => {
    // A command carries no `text` at all: the command line is in `command`
    // and its output in `aggregatedOutput`. Looking only for `text` judged
    // every one of them to be carrying nothing and dropped it, so the
    // transcript showed the narration about running commands and never the
    // commands.
    const seen: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => seen.push(item) });

    socket.emit({
      method: "item/completed",
      params: {
        item: {
          type: "commandExecution",
          id: "c-1",
          command: "cargo test -p opencli-core",
          cwd: "/work",
          status: "completed",
          aggregatedOutput: "test result: ok. 1022 passed",
          exitCode: 0,
          durationMs: 19440,
        },
      },
    });

    expect(seen).toHaveLength(1);
    expect(seen[0].kind).toBe("command");
    expect(seen[0].text).toBe("cargo test -p opencli-core");
    expect(seen[0].output).toBe("test result: ok. 1022 passed");
    expect(seen[0].durationMs).toBe(19440);
  });

  it("should say what a command does, from the server's parse of it", async () => {
    // A local model usually leaves an optional description empty, so the
    // parse is the ordinary case rather than a rarely-used fallback.
    const seen: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => seen.push(item) });

    socket.emit({
      method: "item/completed",
      params: {
        item: {
          type: "commandExecution",
          id: "c-1",
          command: "bash -lc 'cat src/markdown.tsx'",
          commandActions: [{ type: "read", name: "markdown.tsx", path: "src/markdown.tsx" }],
          status: "completed",
        },
      },
    });

    expect(seen[0].summary).toBe("Read markdown.tsx");
    // The command itself is still there; the summary heads it, not replaces it.
    expect(seen[0].text).toBe("bash -lc 'cat src/markdown.tsx'");
  });

  it("should prefer the model's own words when it wrote any", async () => {
    const seen: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => seen.push(item) });

    socket.emit({
      method: "item/completed",
      params: {
        item: {
          type: "commandExecution",
          id: "c-2",
          command: "bash -lc 'cat src/markdown.tsx'",
          description: "Check how emphasis is parsed",
          commandActions: [{ type: "read", name: "markdown.tsx" }],
          status: "completed",
        },
      },
    });

    expect(seen[0].summary).toBe("Check how emphasis is parsed");
  });

  it("should say nothing rather than guess at an unrecognised command", async () => {
    // A row that invents a description of a command it did not understand is
    // worse than one that simply shows the command.
    const seen: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => seen.push(item) });

    socket.emit({
      method: "item/completed",
      params: {
        item: {
          type: "commandExecution",
          id: "c-3",
          command: "cargo test -p opencli-api",
          commandActions: [{ type: "unknown", command: "cargo test -p opencli-api" }],
          status: "completed",
        },
      },
    });

    expect(seen[0].summary).toBeUndefined();
  });

  it("should name the tool an MCP call went to", async () => {
    const seen: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => seen.push(item) });

    socket.emit({
      method: "item/completed",
      params: {
        item: {
          type: "mcpToolCall",
          id: "m-1",
          server: "figma",
          tool: "get_design_context",
          status: "completed",
          arguments: { text: "node 12:34" },
          result: { text: "a frame" },
        },
      },
    });

    expect(seen[0].kind).toBe("command");
    expect(seen[0].tool).toBe("figma · get_design_context");
    expect(seen[0].output).toBe("a frame");
  });

  it("should still drop an item that really carries nothing", async () => {
    // The emptiness check is what keeps housekeeping items out of the
    // transcript; widening it must not turn that off.
    const seen: ThreadItem[] = [];
    const { socket } = await connected({ onItem: (item: ThreadItem) => seen.push(item) });

    socket.emit({
      method: "item/completed",
      params: { item: { type: "contextCompaction", id: "x-1" } },
    });

    expect(seen).toHaveLength(0);
  });
});

describe("a reply being written", () => {
  it("should show text as it arrives rather than only when it is finished", async () => {
    // Without this a reply appears in one lump at the end. On a local model
    // that is minutes of a spinner with nothing to show, which cannot be told
    // apart from a hang.
    const seen: string[] = [];
    const { socket } = await connected({
      onItemDelta: (item: ThreadItem) => seen.push(item.text),
    });

    socket.emit({
      method: "item/agentMessage/delta",
      params: { itemId: "i-1", delta: "Quick" },
    });
    socket.emit({
      method: "item/agentMessage/delta",
      params: { itemId: "i-1", delta: "sort " },
    });
    socket.emit({
      method: "item/agentMessage/delta",
      params: { itemId: "i-1", delta: "divides." },
    });

    // Each one carries everything written so far, so the caller can replace
    // rather than having to accumulate.
    expect(seen).toEqual(["Quick", "Quicksort ", "Quicksort divides."]);
  });

  it("should show a model thinking, which is all there is to show at first", async () => {
    // A reasoning model streams its thinking as `reasoning` while `content`
    // stays an empty string. Handling only the answer meant minutes of a
    // blank screen while the model was demonstrably working.
    const seen: { kind: string; text: string }[] = [];
    const { socket } = await connected({
      onItemDelta: (item: ThreadItem) => seen.push({ kind: item.kind, text: item.text }),
    });

    socket.emit({
      method: "item/reasoning/textDelta",
      params: { itemId: "r-1", delta: "We need" },
    });
    socket.emit({
      method: "item/reasoning/textDelta",
      params: { itemId: "r-1", delta: " to respond." },
    });
    socket.emit({
      method: "item/agentMessage/delta",
      params: { itemId: "m-1", delta: "ready" },
    });

    expect(seen).toEqual([
      { kind: "reasoning", text: "We need" },
      { kind: "reasoning", text: "We need to respond." },
      { kind: "agent", text: "ready" },
    ]);
  });

  it("should ignore the empty content a thinking model sends alongside", async () => {
    // Every reasoning chunk carries `content: ""`. Treating that as an update
    // would replace the message with nothing on every thought.
    const seen: string[] = [];
    const { socket } = await connected({
      onItemDelta: (item: ThreadItem) => seen.push(item.text),
    });

    socket.emit({ method: "item/agentMessage/delta", params: { itemId: "m-1", delta: "ok" } });
    socket.emit({ method: "item/agentMessage/delta", params: { itemId: "m-1", delta: "" } });

    expect(seen).toEqual(["ok"]);
  });

  it("should keep two replies apart while both are being written", async () => {
    const seen: Record<string, string> = {};
    const { client, socket } = await connected({
      onItemDelta: (item: ThreadItem) => {
        seen[item.id] = item.text;
      },
    });

    socket.emit({ method: "item/agentMessage/delta", params: { itemId: "a", delta: "one" } });
    socket.emit({ method: "item/agentMessage/delta", params: { itemId: "b", delta: "two" } });
    socket.emit({ method: "item/agentMessage/delta", params: { itemId: "a", delta: " more" } });

    expect(seen).toEqual({ a: "one more", b: "two" });
    void client;
  });

  it("should start afresh when an item is written twice in a session", async () => {
    // The buffer has to be forgotten when the finished item arrives, or a
    // second reply would be appended to the first.
    const seen: string[] = [];
    const { socket } = await connected({
      onItemDelta: (item: ThreadItem) => seen.push(item.text),
    });

    socket.emit({ method: "item/agentMessage/delta", params: { itemId: "i-1", delta: "first" } });
    socket.emit({
      method: "item/completed",
      params: { item: { type: "agentMessage", id: "i-1", text: "first" } },
    });
    socket.emit({ method: "item/agentMessage/delta", params: { itemId: "i-1", delta: "second" } });

    expect(seen).toEqual(["first", "second"]);
  });
});

describe("every model, wherever it lives", () => {
  beforeEach(() => {
    FakeSocket.answer = null;
  });

  it("should merge the models of every machine into one list", async () => {
    // The question the Models page answers is "what do I have", not "what is
    // on this box". Scoping it to one machine is what made models spread
    // across several invisible unless you went looking.
    FakeSocket.answer = (message) => {
      const baseUrl = message.params?.baseUrl;
      switch (message.method) {
        case "server/list":
          return {
            data: [
              { id: "s1", name: "GPU Box", baseUrl: "https://gpu.example", runtime: "ollama" },
              { id: "s2", name: "Spare", baseUrl: "https://spare.example", runtime: "ollama" },
            ],
          };
        case "runtime/discover":
          return { data: [] };
        case "runtime/models":
          return baseUrl === "https://gpu.example"
            ? { data: [{ name: "qwen2.5-coder:7b", size: 4_700_000_000 }] }
            : { data: [{ name: "llama3.1:8b", size: 4_900_000_000 }] };
        case "runtime/show":
          return { supportsTools: true, contextLength: 32768 };
        default:
          return undefined;
      }
    };

    const { client } = await connected();
    const rows = await client.allInstalledModels();

    expect(rows.map((row) => [row.model.name, row.server])).toEqual([
      ["llama3.1:8b", "Spare"],
      ["qwen2.5-coder:7b", "GPU Box"],
    ]);
  });

  it("should not hold the list while it asks what each model can do", async () => {
    // Asking costs a round trip per model — 2.5 seconds each against a server
    // across the internet. Waiting for all of them turned a one-second answer
    // into a five-second one, so they arrive after the list.
    FakeSocket.answer = (message) => {
      switch (message.method) {
        case "server/list":
          return {
            data: [{ id: "s1", name: "Box", baseUrl: "https://box.example", runtime: "ollama" }],
          };
        case "runtime/discover":
          return { data: [] };
        case "runtime/models":
          return { data: [{ name: "qwen2.5:3b", size: 1 }] };
        case "runtime/show":
          return { supportsTools: true, contextLength: 32768 };
        default:
          return undefined;
      }
    };

    const { client } = await connected();
    const rows = await client.allInstalledModels();

    // The list is complete; what each model can do is not waited for.
    expect(rows).toHaveLength(1);
    expect(rows[0].model.name).toBe("qwen2.5:3b");
    expect(rows[0].capabilities).toBeUndefined();
  });

  it("should report what each model can do once it knows", async () => {
    FakeSocket.answer = (message) => {
      switch (message.method) {
        case "server/list":
          return {
            data: [{ id: "s1", name: "Box", baseUrl: "https://box.example", runtime: "ollama" }],
          };
        case "runtime/discover":
          return { data: [] };
        case "runtime/models":
          return { data: [{ name: "qwen2.5:3b", size: 1 }] };
        case "runtime/show":
          return { supportsTools: true, contextLength: 32768 };
        default:
          return undefined;
      }
    };

    const updates: (number | null | undefined)[] = [];
    const { client } = await connected();
    await client.allInstalledModels((rows) =>
      updates.push(rows[0]?.capabilities?.contextLength),
    );
    await settle();
    await settle();

    // Called once when the machine named its models, and again once what they
    // can do was known.
    expect(updates[0]).toBeUndefined();
    expect(updates.at(-1)).toBe(32768);
  });

  it("should still list the reachable machines when one is down", async () => {
    // A server that is off should cost its own models and nothing else.
    // Failing the whole call would empty a page that is mostly correct.
    FakeSocket.answer = (message) => {
      const baseUrl = message.params?.baseUrl;
      switch (message.method) {
        case "server/list":
          return {
            data: [
              { id: "s1", name: "Up", baseUrl: "https://up.example", runtime: "ollama" },
              { id: "s2", name: "Down", baseUrl: "https://down.example", runtime: "ollama" },
            ],
          };
        case "runtime/discover":
          return { data: [] };
        case "runtime/models":
          return baseUrl === "https://up.example"
            ? { data: [{ name: "mistral:7b", size: 4_100_000_000 }] }
            : FakeSocket.rpcError("could not reach it");
        case "runtime/show":
          return { supportsTools: true };
        default:
          return undefined;
      }
    };

    const { client } = await connected();
    const rows = await client.allInstalledModels();

    expect(rows).toHaveLength(1);
    expect(rows[0].server).toBe("Up");
  });

  it("should not list a discovered runtime twice when it is also saved", async () => {
    // Ollama on this machine is both found by probing and saved by the user;
    // showing its models twice would read as two copies of one model.
    FakeSocket.answer = (message) => {
      switch (message.method) {
        case "server/list":
          return {
            data: [
              { id: "s1", name: "Mine", baseUrl: "http://localhost:11434", runtime: "ollama" },
            ],
          };
        case "runtime/discover":
          return {
            data: [
              {
                runtime: "ollama",
                name: "Ollama",
                baseUrl: "http://localhost:11434",
                version: "0.33.2",
                manageable: true,
              },
            ],
          };
        case "runtime/models":
          return { data: [{ name: "qwen3:8b", size: 5_200_000_000 }] };
        case "runtime/show":
          return { supportsTools: true };
        default:
          return undefined;
      }
    };

    const { client } = await connected();
    expect(await client.allInstalledModels()).toHaveLength(1);
  });
});

describe("choosing where to install", () => {
  beforeEach(() => {
    FakeSocket.answer = null;
  });

  it("should list machines without waiting to read their memory", async () => {
    FakeSocket.answer = (message) => {
      const baseUrl = message.params?.baseUrl;
      switch (message.method) {
        case "server/list":
          return {
            data: [
              { id: "s1", name: "GPU Box", baseUrl: "https://gpu.example", runtime: "ollama" },
              { id: "s2", name: "Off", baseUrl: "https://off.example", runtime: "ollama" },
            ],
          };
        case "runtime/discover":
          return { data: [] };
        case "runtime/probe":
          return { reachable: baseUrl === "https://gpu.example" };
        case "runtime/models":
          return baseUrl === "https://gpu.example"
            ? { data: [{ name: "qwen2.5-coder:7b", size: 1 }] }
            : FakeSocket.rpcError("could not reach it");
        case "server/diagnose":
          return { http: { reachable: true }, shell: { gpu: "32607 MiB" }, findings: [] };
        default:
          return undefined;
      }
    };

    const { client, socket } = await connected();
    const targets = await client.installTargets();

    const gpu = targets.find((target) => target.label === "GPU Box")!;
    expect(gpu.reachable).toBe(true);
    expect(gpu.installed).toContain("qwen2.5-coder:7b");

    const off = targets.find((target) => target.label === "Off")!;
    expect(off.reachable).toBe(false);
    expect(off.installed).toEqual([]);

    // Diagnosing is an SSH round trip per machine. Doing it here meant the
    // install dialog showed nothing for six seconds against one remote server.
    expect(socket.parsedSent().some((sent) => sent.method === "server/diagnose")).toBe(false);
  });

  it("should read memory for one machine, from nvidia-smi", async () => {
    FakeSocket.answer = (message) => {
      switch (message.method) {
        case "server/list":
          return {
            data: [
              {
                id: "s1",
                name: "GPU Box",
                baseUrl: "https://gpu.example",
                runtime: "ollama",
                sshAlias: "gpubox",
              },
            ],
          };
        case "server/diagnose":
          return {
            http: { reachable: true },
            shell: { gpu: "NVIDIA RTX 5090, 32607 MiB" },
            findings: [],
          };
        default:
          return undefined;
      }
    };

    const { client } = await connected();
    expect(await client.machineMemoryGb("https://gpu.example")).toBe(32);
  });

  it("should not claim a memory figure for a machine it cannot log in to", async () => {
    // Without an SSH alias there is no shell to ask. Guessing would be worse
    // than saying nothing: the figure decides which version gets recommended.
    FakeSocket.answer = (message) => {
      if (message.method === "server/list") {
        return {
          data: [
            {
              id: "s1",
              name: "Just a URL",
              baseUrl: "https://plain.example",
              runtime: "ollama",
              sshAlias: null,
            },
          ],
        };
      }
      return undefined;
    };

    const { client, socket } = await connected();
    expect(await client.machineMemoryGb("https://plain.example")).toBeNull();
    expect(socket.parsedSent().some((sent) => sent.method === "server/diagnose")).toBe(false);
  });

  it("should leave the fit unstated when memory cannot be read", async () => {
    // A machine with no SSH alias cannot be asked how much memory it has.
    // Guessing would be worse than saying nothing: the guess decides which
    // quantisation gets recommended.
    FakeSocket.answer = (message) => {
      switch (message.method) {
        case "server/list":
          return { data: [] };
        case "runtime/discover":
          return {
            data: [
              {
                runtime: "ollama",
                name: "Ollama",
                baseUrl: "http://localhost:11434",
                version: "0.33.2",
                manageable: true,
              },
            ],
          };
        case "runtime/probe":
          return { reachable: true };
        case "runtime/models":
          return { data: [] };
        default:
          return undefined;
      }
    };

    const { client } = await connected();
    const targets = await client.installTargets();

    expect(targets).toHaveLength(1);
    expect(targets[0].memoryGb).toBeNull();
  });
});
