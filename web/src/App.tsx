import { useCallback, useEffect, useRef, useState } from "react";
import Sidebar, { type View } from "./Sidebar";
import {
  ConnectorsView,
  ProjectsView,
  ScheduledView,
  SettingsView,
  SkillsView,
} from "./views";
import {
  OpenCliClient,
  type ApprovalRequest,
  type ConnectionStatus,
  type ModelOption,
  type Project,
  type ThreadItem,
  type ThreadSummary,
} from "./protocol";
import "./styles.css";

/**
 * The gateway prints a URL containing a one-time token. Accept it in the
 * address bar (`?gateway=ws://...&token=...`) and fall back to a form.
 */
function gatewayUrlFromLocation(): string {
  const params = new URLSearchParams(window.location.search);
  const gateway = params.get("gateway") ?? "ws://127.0.0.1:4517/ws";
  const token = params.get("token");
  return token ? `${gateway}?token=${encodeURIComponent(token)}` : gateway;
}

interface TauriBridge {
  invoke(command: string): Promise<unknown>;
}

function bridge(): TauriBridge | null {
  return (window as unknown as { __TAURI__?: { core?: TauriBridge } }).__TAURI__?.core ?? null;
}

function isDesktop(): boolean {
  return bridge() !== null;
}

/**
 * Ask the desktop host for a value it alone knows: the gateway binds a random
 * port at startup, and a desktop launch has no shell to inherit a directory
 * from. Returns `null` in the browser build, where the user supplies both.
 */
async function fromHost(command: "gateway_url" | "default_cwd"): Promise<string | null> {
  const core = bridge();
  if (!core) return null;
  try {
    const value = await core.invoke(command);
    return typeof value === "string" ? value : null;
  } catch {
    return null;
  }
}

const KIND_LABEL: Record<ThreadItem["kind"], string> = {
  user: "You",
  agent: "OpenCLI",
  command: "Command",
  reasoning: "Thinking",
  other: "",
};

export default function App() {
  const [url, setUrl] = useState(gatewayUrlFromLocation);
  const [cwd, setCwd] = useState("");
  const [status, setStatus] = useState<ConnectionStatus | "idle">("idle");
  const [view, setView] = useState<View>("chat");

  const [items, setItems] = useState<ThreadItem[]>([]);
  const [threads, setThreads] = useState<ThreadSummary[]>([]);
  const [activeThreadId, setActiveThreadId] = useState<string | null>(null);
  const [models, setModels] = useState<ModelOption[]>([]);
  const [model, setModel] = useState<string>("");

  const [project, setProject] = useState<Project | null>(null);
  const [approval, setApproval] = useState<ApprovalRequest | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);

  const clientRef = useRef<OpenCliClient | null>(null);
  const transcriptRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    transcriptRef.current?.scrollTo({ top: transcriptRef.current.scrollHeight });
  }, [items, approval]);

  /** Refresh the sidebar; failures here must not break the chat. */
  const refreshThreads = useCallback(async () => {
    try {
      const listed = await (clientRef.current?.listThreads() ?? Promise.resolve([]));
      setThreads(listed);
    } catch {
      // Listing is a convenience; leave the previous list in place.
    }
  }, []);

  const connectTo = useCallback(
    async (target: string, directory: string, instructions?: string) => {
      setError(null);
      const client = new OpenCliClient({
        onStatus: setStatus,
        // The client only surfaces completed items, so each one is new.
        onItem: (item) => setItems((prev) => [...prev, item]),
        onTurnComplete: () => {
          setBusy(false);
          void refreshThreads();
        },
        onError: (message) => {
          setError(message);
          setBusy(false);
        },
        onApprovalRequest: setApproval,
      });
      clientRef.current = client;
      try {
        await client.connect(target, { cwd: directory || ".", instructions });
        setActiveThreadId(client.threadId);
        const available = await client.listModels();
        setModels(available);
        setModel((current) => current || available[0]?.model || "");
        void refreshThreads();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        setStatus("error");
      }
    },
    [refreshThreads],
  );

  const connect = useCallback(() => connectTo(url, cwd), [connectTo, url, cwd]);

  // The desktop app must be usable the moment its window appears: there is no
  // URL to paste and no shell to inherit a directory from. Wait for the
  // in-process gateway to bind, then connect without asking anything.
  useEffect(() => {
    if (!isDesktop()) return;
    let cancelled = false;
    let attempts = 0;

    const start = async () => {
      const hosted = await fromHost("gateway_url");
      if (cancelled) return;
      if (!hosted) {
        if (attempts++ < 40) {
          setTimeout(() => void start(), 250);
        } else {
          setError("the agent did not start; see the application logs");
          setStatus("error");
        }
        return;
      }
      const home = (await fromHost("default_cwd")) ?? ".";
      if (cancelled) return;
      setUrl(hosted);
      setCwd(home);
      void connectTo(hosted, home);
    };

    setStatus("connecting");
    void start();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const send = useCallback(async () => {
    const text = draft.trim();
    const client = clientRef.current;
    if (!text || !client) return;
    setDraft("");
    setBusy(true);
    // The server echoes the user message back as a thread item, so do not add
    // it locally — doing so showed every prompt twice.
    try {
      await client.send(text);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setBusy(false);
    }
  }, [draft]);

  const interrupt = useCallback(async () => {
    try {
      await clientRef.current?.interrupt();
    } catch {
      // The turn may have finished between render and click.
    }
    setBusy(false);
  }, []);

  const openThread = useCallback(async (id: string) => {
    const client = clientRef.current;
    if (!client) return;
    setView("chat");
    setItems([]);
    try {
      await client.resumeThread(id);
      setActiveThreadId(id);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, []);

  const openProject = useCallback(
    async (target: Project) => {
      setView("chat");
      setItems([]);
      setProject(target);
      setCwd(target.cwd);
      await connectTo(url, target.cwd, target.instructions);
      const client = clientRef.current;
      // Attach after connecting, so the project lists the thread that was
      // actually opened. A failure here only costs the grouping.
      if (client?.threadId) {
        try {
          await client.attachThread(target.id, client.threadId);
        } catch {
          // Not worth interrupting the chat that just opened successfully.
        }
      }
    },
    [connectTo, url],
  );

  const newChat = useCallback(async () => {
    setView("chat");
    setItems([]);
    setProject(null);
    await connectTo(url, cwd);
  }, [connectTo, url, cwd]);

  const answerApproval = useCallback(
    (decision: "approved" | "denied") => {
      if (!approval) return;
      clientRef.current?.respondToApproval(approval.id, decision);
      setApproval(null);
    },
    [approval],
  );

  if (status !== "ready" && isDesktop()) {
    return (
      <main className="connect">
        <h1>OpenCLI</h1>
        <p className="hint">
          {status === "error" ? "The agent could not be started." : "Starting the agent…"}
        </p>
        {error ? <p className="error">{error}</p> : null}
      </main>
    );
  }

  if (status !== "ready") {
    return (
      <main className="connect">
        <h1>OpenCLI</h1>
        <p className="hint">
          Start the gateway with <code>opencli serve</code> and paste the URL it prints. It
          contains a one-time token.
        </p>
        <label>
          Gateway URL
          <input value={url} onChange={(e) => setUrl(e.target.value)} />
        </label>
        <label>
          Working directory
          <input
            value={cwd}
            onChange={(e) => setCwd(e.target.value)}
            placeholder="/path/to/project"
          />
        </label>
        <button onClick={connect} disabled={status === "connecting"}>
          {status === "connecting" ? "Connecting…" : "Connect"}
        </button>
        {error ? <p className="error">{error}</p> : null}
        <p className="warning">The agent runs commands on the machine hosting the gateway.</p>
      </main>
    );
  }

  const client = clientRef.current;

  return (
    <div className="shell">
      <Sidebar
        view={view}
        threads={threads}
        activeThreadId={activeThreadId}
        onNavigate={setView}
        onNewChat={() => void newChat()}
        onOpenThread={(id) => void openThread(id)}
      />

      <main className="chat">
        <header>
          <span className="badge">connected</span>
          {project ? <span className="badge project">{project.name}</span> : null}
          <span className="cwd">{cwd || "."}</span>
          <select
            className="model"
            value={model}
            onChange={(e) => setModel(e.target.value)}
            title="Model for new chats"
          >
            {models.length === 0 ? <option value="">no models configured</option> : null}
            {models.map((option) => (
              <option key={option.id} value={option.model}>
                {option.displayName}
              </option>
            ))}
          </select>
        </header>

        {view === "projects" && client ? (
          <ProjectsView client={client} onOpen={(target) => void openProject(target)} />
        ) : view === "scheduled" && client ? (
          <ScheduledView client={client} cwd={cwd || "."} />
        ) : view === "skills" && client ? (
          <SkillsView client={client} cwd={cwd || "."} />
        ) : view === "connectors" && client ? (
          <ConnectorsView client={client} />
        ) : view === "settings" && client ? (
          <SettingsView client={client} />
        ) : (
          <>
            <div className="transcript" ref={transcriptRef}>
              {items.length === 0 ? (
                <p className="muted">Ask OpenCLI to do anything in {cwd || "."}.</p>
              ) : null}
              {items.map((item) => (
                <article key={item.id} className={`item ${item.kind}`}>
                  {KIND_LABEL[item.kind] ? (
                    <span className="label">{KIND_LABEL[item.kind]}</span>
                  ) : null}
                  <pre>{item.text}</pre>
                  {item.exitCode !== undefined && item.exitCode !== 0 ? (
                    <span className="exit">exit {item.exitCode}</span>
                  ) : null}
                </article>
              ))}
              {busy ? (
                <p className="working">
                  Working…{" "}
                  <button className="link" onClick={() => void interrupt()}>
                    stop
                  </button>
                </p>
              ) : null}
            </div>

            {approval ? (
              <div className="approval" role="dialog" aria-label="Approval required">
                <p>The agent wants to run:</p>
                <pre>{approval.command}</pre>
                <div className="actions">
                  <button onClick={() => answerApproval("approved")}>Approve</button>
                  <button className="secondary" onClick={() => answerApproval("denied")}>
                    Deny
                  </button>
                </div>
              </div>
            ) : null}

            {error ? <p className="error">{error}</p> : null}

            <form
              className="composer"
              onSubmit={(e) => {
                e.preventDefault();
                void send();
              }}
            >
              <textarea
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    void send();
                  }
                }}
                placeholder="Ask OpenCLI to do anything"
                rows={3}
              />
              <button type="submit" disabled={busy || !draft.trim()}>
                Send
              </button>
            </form>
          </>
        )}
      </main>
    </div>
  );
}
