import { useCallback, useEffect, useRef, useState } from "react";
import Sidebar, { type View } from "./Sidebar";
import {
  ApprovalChanges,
  ArtifactsView,
  ConnectorsView,
  CustomizeView,
  MemoryView,
  ProjectsView,
  ScheduledView,
  SettingsView,
  SkillsView,
} from "./views";
import {
  OpenCliClient,
  type ApprovalRequest,
  type ConnectionStatus,
  type FileChange,
  type ModelOption,
  type Attachment,
  type ConnectorSummary,
  type Preferences,
  type Project,
  type ScheduledTask,
  type SkillSummary,
  type ThreadItem,
  type ThreadSummary,
} from "./protocol";
import {
  ChevronIcon,
  ClockIcon,
  FolderIcon,
  PanelIcon,
  PlusIcon,
  ProjectIcon,
  SendIcon,
  SidebarToggleIcon,
  StopIcon,
  SunburstIcon,
} from "./icons";
import { AttachMenu, ModelMenu, Popover } from "./menus";
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
  invoke(command: string, args?: Record<string, unknown>): Promise<unknown>;
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

/**
 * Open the platform's folder chooser, if the host offers one.
 *
 * Returns `null` in the browser build and when the user cancels — in both
 * cases the caller should leave whatever path is already there.
 */
/**
 * Open the platform's file chooser, if the host offers one.
 *
 * Only the desktop build can attach a file: the browser hands over a `File`
 * with no path, and a path is what the agent needs to read it.
 */
export async function chooseFiles(): Promise<{ name: string; path: string }[]> {
  const core = bridge();
  if (!core) return [];
  try {
    const chosen = await core.invoke("choose_files");
    if (!Array.isArray(chosen)) return [];
    return chosen
      .filter((path): path is string => typeof path === "string" && path.length > 0)
      .map((path) => ({ name: path.split("/").pop() || path, path }));
  } catch {
    return [];
  }
}

export async function chooseDirectory(start: string): Promise<string | null> {
  const core = bridge();
  if (!core) return null;
  try {
    const chosen = await core.invoke("choose_directory", { start });
    return typeof chosen === "string" && chosen ? chosen : null;
  } catch {
    return null;
  }
}

/** Images the composer will inline; anything else is referenced by path. */
function isImage(file: File): boolean {
  return file.type.startsWith("image/");
}

/** Read a file as a data URL so it can be inlined in a message. */
function readAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error(`could not read ${file.name}`));
    reader.readAsDataURL(file);
  });
}

/**
 * Turn dropped or pasted files into attachments.
 *
 * A browser `File` has no path, so a non-image can only be referenced when the
 * host gives us one — otherwise it is skipped with a reason rather than
 * silently dropped.
 */
async function toAttachments(files: File[]): Promise<{ ok: Attachment[]; skipped: string[] }> {
  const ok: Attachment[] = [];
  const skipped: string[] = [];
  for (const file of files) {
    if (isImage(file)) {
      try {
        ok.push({ kind: "image", name: file.name || "pasted image", dataUrl: await readAsDataUrl(file) });
      } catch {
        skipped.push(file.name);
      }
    } else {
      skipped.push(file.name);
    }
  }
  return { ok, skipped };
}

/** When a scheduled task last ran, in the words a person would use. */
function describeRun(task: ScheduledTask): string {
  if (!task.lastRun) return "not run yet";
  const days = Math.floor((Date.now() / 1000 - task.lastRun) / 86400);
  if (days <= 0) return "today";
  if (days === 1) return "yesterday";
  return `${days} days ago`;
}

const KIND_LABEL: Record<ThreadItem["kind"], string> = {
  user: "You",
  agent: "OpenCLI",
  command: "Command",
  reasoning: "Thinking",
  fileChange: "Files",
  other: "",
};

export default function App() {
  const [url, setUrl] = useState(gatewayUrlFromLocation);
  const [cwd, setCwd] = useState("");
  const [status, setStatus] = useState<ConnectionStatus | "idle">("idle");
  const [view, setView] = useState<View>("chat");
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [detailsOpen, setDetailsOpen] = useState(false);
  // Where the user has been, so back and forward mean something. Kept as
  // views rather than URLs: this app has no address bar to sync with.
  const [history, setHistory] = useState<View[]>(["chat"]);
  const [historyAt, setHistoryAt] = useState(0);

  const [items, setItems] = useState<ThreadItem[]>([]);
  const [threads, setThreads] = useState<ThreadSummary[]>([]);
  const [projectList, setProjectList] = useState<Project[]>([]);
  const [taskList, setTaskList] = useState<ScheduledTask[]>([]);
  const [skillList, setSkillList] = useState<SkillSummary[]>([]);
  const [connectorList, setConnectorList] = useState<ConnectorSummary[]>([]);
  const [attachMenu, setAttachMenu] = useState(false);
  const [modelMenu, setModelMenu] = useState(false);
  const [activeThreadId, setActiveThreadId] = useState<string | null>(null);
  const [models, setModels] = useState<ModelOption[]>([]);
  const [model, setModel] = useState<string>("");

  const [project, setProject] = useState<Project | null>(null);
  const [changes, setChanges] = useState<FileChange[]>([]);
  const [preferences, setPreferences] = useState<Preferences>({ approvalPolicy: "untrusted" });
  const [approval, setApproval] = useState<ApprovalRequest | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [attachments, setAttachments] = useState<Attachment[]>([]);
  const [busy, setBusy] = useState(false);

  const clientRef = useRef<OpenCliClient | null>(null);
  const modelRef = useRef<string>("");
  // Skills are listed per directory, and this refresh runs from callbacks
  // created before the directory is known.
  const cwdRef = useRef<string>("");
  // Same reason as the model: `connectTo` is created before the user has had a
  // chance to change anything, so closing over the state would pin every
  // thread to the initial preferences.
  const preferencesRef = useRef<Preferences>(preferences);
  const transcriptRef = useRef<HTMLDivElement>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    transcriptRef.current?.scrollTo({ top: transcriptRef.current.scrollHeight });
  }, [items, approval]);

  /**
   * Navigate, recording the step.
   *
   * Anything after the current position is dropped, which is what a browser
   * does: once you go back and then somewhere new, the branch you left is no
   * longer reachable and keeping it would make "forward" unpredictable.
   */
  const go = useCallback(
    (next: View) => {
      setView(next);
      setHistory((prev) => {
        const trimmed = prev.slice(0, historyAt + 1);
        if (trimmed[trimmed.length - 1] === next) return trimmed;
        setHistoryAt(trimmed.length);
        return [...trimmed, next];
      });
    },
    [historyAt],
  );

  const step = useCallback(
    (delta: number) => {
      const at = historyAt + delta;
      if (at < 0 || at >= history.length) return;
      setHistoryAt(at);
      setView(history[at]);
    },
    [history, historyAt],
  );

  useEffect(() => {
    modelRef.current = model;
  }, [model]);

  useEffect(() => {
    preferencesRef.current = preferences;
  }, [preferences]);

  useEffect(() => {
    cwdRef.current = cwd;
  }, [cwd]);

  /** Refresh the sidebar; failures here must not break the chat. */
  const refreshThreads = useCallback(async () => {
    const client = clientRef.current;
    if (!client) return;
    // Each list decorates the sidebar independently, so one failing should not
    // blank the others.
    const [listed, projects, tasks, skills, connectors] = await Promise.all([
      client.listThreads().catch(() => null),
      client.listProjects().catch(() => null),
      client.listTasks().catch(() => null),
      client.listSkills(cwdRef.current || ".").catch(() => null),
      client.listConnectors().catch(() => null),
    ]);
    if (listed) setThreads(listed);
    if (projects) setProjectList(projects);
    if (tasks) setTaskList(tasks);
    if (skills) setSkillList(skills);
    if (connectors) setConnectorList(connectors);
  }, []);

  /**
   * Start a thread on an open session.
   *
   * Separate from connecting because they are different costs: a new chat is a
   * new thread, not a new connection. Reconnecting for one would drop the
   * socket, send the app back to its starting screen, and read as the window
   * reopening.
   */
  const openThreadOn = useCallback(
    async (
      client: OpenCliClient,
      directory: string,
      instructions?: string,
      projectId: string | null = null,
    ) => {
      let remembered = "";
      try {
        remembered = (await client.listMemories({ projectId, applicableOnly: true })).instructions;
      } catch {
        // Memory is an enhancement; a chat must still open without it.
      }
      await client.startThread({
        cwd: directory || ".",
        // Read from the ref, not the `model` state: this is created before the
        // first model list arrives, so closing over the state would pin every
        // thread to the empty initial value.
        ...(modelRef.current ? { model: modelRef.current } : {}),
        preferences: preferencesRef.current,
        instructions: [instructions, remembered].filter(Boolean).join("\n\n"),
      });
      setActiveThreadId(client.threadId);
    },
    [],
  );

  /**
   * Begin a fresh chat, reusing the connection when there is one.
   *
   * Falls back to connecting only when there is nothing to reuse, which is the
   * first run and after a dropped socket.
   */
  const startFreshThread = useCallback(
    async (directory: string, instructions?: string, projectId: string | null = null) => {
      const client = clientRef.current;
      if (!client) return null;
      setError(null);
      setItems([]);
      setChanges([]);
      try {
        await openThreadOn(client, directory, instructions, projectId);
        void refreshThreads();
        return client;
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        return null;
      }
    },
    [openThreadOn, refreshThreads],
  );

  const connectTo = useCallback(
    async (
      target: string,
      directory: string,
      instructions?: string,
      projectId: string | null = null,
    ) => {
      setError(null);
      const client = new OpenCliClient({
        onStatus: setStatus,
        // The client only surfaces completed items, so each one is new.
        onItem: (item) => {
          setItems((prev) => [...prev, item]);
          if (item.changes?.length) {
            setChanges((prev) => [...prev, ...item.changes!]);
          }
        },
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
      // Replacing the socket without closing it leaks a connection per reconnect.
      clientRef.current?.close();
      clientRef.current = client;
      try {
        // Handshake first, so the applicable memories can be read on this same
        // connection — a thread's instructions must be settled before it
        // starts, and `memory/*` is answered by the gateway, not the thread.
        await client.openSession(target);
        await openThreadOn(client, directory, instructions, projectId);
        const available = await client.listModels();
        setModels(available);
        setModel((current) => {
          const next = current || available[0]?.model || "";
          modelRef.current = next;
          return next;
        });
        void refreshThreads();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        setStatus("error");
      }
    },
    [openThreadOn, refreshThreads],
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

  const attach = useCallback(async (files: File[]) => {
    if (files.length === 0) return;
    const { ok, skipped } = await toAttachments(files);
    if (ok.length > 0) setAttachments((prev) => [...prev, ...ok]);
    if (skipped.length > 0) {
      setError(
        `Dropped files are inlined only when they are images. Skipped: ${skipped.join(", ")}. ` +
          (isDesktop()
            ? "Use “Attach file” to reference one by path instead."
            : "Name the file by path in your message — the agent can read it."),
      );
    }
  }, []);

  const send = useCallback(async () => {
    const text = draft.trim();
    const client = clientRef.current;
    if ((!text && attachments.length === 0) || !client) return;
    const sending = attachments;
    setDraft("");
    setAttachments([]);
    setBusy(true);
    // The server echoes the user message back as a thread item, so do not add
    // it locally — doing so showed every prompt twice.
    try {
      await client.send(text, {
        effort: preferencesRef.current.effort,
        attachments: sending,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setBusy(false);
    }
  }, [attachments, draft]);

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
    go("chat");
    setItems([]);
    setChanges([]);
    try {
      setItems(await client.resumeThread(id));
      setActiveThreadId(id);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, []);

  const openProject = useCallback(
    async (target: Project) => {
      go("chat");
      setProject(target);
      setCwd(target.cwd);
      const client = await startFreshThread(target.cwd, target.instructions, target.id);
      // Attach after the thread exists, so the project lists the one that was
      // actually opened. A failure here only costs the grouping.
      if (client?.threadId) {
        try {
          await client.attachThread(target.id, client.threadId);
          void refreshThreads();
        } catch {
          // Not worth interrupting the chat that just opened successfully.
        }
      }
    },
    [go, refreshThreads, startFreshThread],
  );

  const newChat = useCallback(async () => {
    go("chat");
    setProject(null);
    await startFreshThread(cwd);
  }, [cwd, go, startFreshThread]);

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
          <span className="path-input">
            <input
              value={cwd}
              onChange={(e) => setCwd(e.target.value)}
              placeholder="/path/to/project"
            />
            {isDesktop() ? (
              <button
                type="button"
                className="secondary"
                onClick={() => {
                  void chooseDirectory(cwd).then((picked) => picked && setCwd(picked));
                }}
              >
                Browse…
              </button>
            ) : null}
          </span>
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
    <div
      className={`shell${sidebarOpen ? "" : " collapsed"}${detailsOpen ? " with-details" : ""}`}
    >
      <Sidebar
        view={view}
        threads={threads}
        projects={projectList}
        tasks={taskList}
        activeThreadId={activeThreadId}
        activeProjectId={project?.id ?? null}
        onNavigate={go}
        onNewChat={() => void newChat()}
        onOpenThread={(id) => void openThread(id)}
        onOpenProject={(target) => void openProject(target)}
        onToggle={() => setSidebarOpen(false)}
        onBack={() => step(-1)}
        onForward={() => step(1)}
        canBack={historyAt > 0}
        canForward={historyAt < history.length - 1}
        onRenameThread={(id, name) => {
          void clientRef.current
            ?.renameThread(id, name)
            .then(refreshThreads)
            .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
        }}
        onArchiveThread={(id) => {
          void clientRef.current
            ?.archiveThread(id)
            .then(refreshThreads)
            .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
        }}
      />

      <main className="chat">
        <header data-tauri-drag-region>
          {sidebarOpen ? null : (
            <button
              className="icon-button sm"
              title="Show sidebar"
              onClick={() => setSidebarOpen(true)}
            >
              <SidebarToggleIcon size={15} />
            </button>
          )}
          <span className="crumb">
            <ProjectIcon size={15} />
            {project ? (
              <>
                <span>{project.name}</span>
                <span className="sep">/</span>
              </>
            ) : null}
            <span className="cwd">{cwd || "."}</span>
          </span>

          <span className="spacer" />

          {changes.length > 0 ? (
            <button className="chip" onClick={() => go("artifacts")}>
              {new Set(changes.map((change) => change.path)).size} changed
            </button>
          ) : null}

          <button
            className={`icon-button sm${detailsOpen ? " on" : ""}`}
            title={detailsOpen ? "Hide details" : "Show details"}
            onClick={() => setDetailsOpen(!detailsOpen)}
          >
            <PanelIcon size={15} />
          </button>
        </header>

        {view === "customize" ? (
          <CustomizeView
            preferences={preferences}
            onChange={setPreferences}
            efforts={models.find((option) => option.model === model)?.reasoningEfforts ?? []}
          />
        ) : view === "artifacts" ? (
          <ArtifactsView changes={changes} />
        ) : view === "memory" && client ? (
          <MemoryView client={client} project={project} />
        ) : view === "projects" && client ? (
          <ProjectsView
            client={client}
            onOpen={(target) => void openProject(target)}
            onBrowse={isDesktop() ? chooseDirectory : undefined}
          />
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
              <div className={`thread${items.length === 0 ? " empty" : ""}`}>
                {items.length === 0 ? (
                  <div className="landing">
                    <h1>
                      <SunburstIcon size={30} />
                      <span>Ready when you are</span>
                    </h1>
                    {taskList.length > 0 ? (
                      <section className="recent">
                        <div className="recent-head">
                          <span>Scheduled</span>
                          <button className="link" onClick={() => go("scheduled")}>
                            Manage
                          </button>
                        </div>
                        <ul>
                          {taskList.slice(0, 5).map((task) => (
                            <li key={task.id}>
                              <ClockIcon size={15} />
                              <span className="what">
                                <strong>{task.name}</strong>
                                <em>{describeRun(task)}</em>
                              </span>
                            </li>
                          ))}
                        </ul>
                      </section>
                    ) : null}
                  </div>
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
            </div>

            {approval ? (
              <div className="approval" role="dialog" aria-label="Approval required">
                <p>
                  {approval.kind === "fileChange"
                    ? "The agent wants to write:"
                    : "The agent wants to run:"}
                </p>
                {approval.kind === "fileChange" ? (
                  <ApprovalChanges changes={approval.changes ?? []} />
                ) : (
                  <pre>{approval.command}</pre>
                )}
                {approval.reason ? <p className="muted">{approval.reason}</p> : null}
                <div className="actions">
                  <button onClick={() => answerApproval("approved")}>Approve</button>
                  <button className="secondary" onClick={() => answerApproval("denied")}>
                    Deny
                  </button>
                </div>
              </div>
            ) : null}

            {error ? (
              <div className="composer-wrap">
                <p className="error">{error}</p>
              </div>
            ) : null}

            <div className="composer-wrap">
            <form
              className="composer"
              onSubmit={(e) => {
                e.preventDefault();
                void send();
              }}
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => {
                e.preventDefault();
                void attach([...e.dataTransfer.files]);
              }}
            >
              {attachments.length > 0 ? (
                <ul className="attachments">
                  {attachments.map((attachment, index) => (
                    <li key={`${attachment.name}-${index}`}>
                      {attachment.kind === "image" ? (
                        <img src={attachment.dataUrl} alt={attachment.name} />
                      ) : null}
                      <span>{attachment.name}</span>
                      <button
                        type="button"
                        aria-label={`Remove ${attachment.name}`}
                        onClick={() =>
                          setAttachments((prev) => prev.filter((_, at) => at !== index))
                        }
                      >
                        ×
                      </button>
                    </li>
                  ))}
                </ul>
              ) : null}

              <textarea
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onPaste={(e) => {
                  // A pasted screenshot arrives as a file on the clipboard with
                  // no name; letting the default run would insert nothing.
                  const files = [...e.clipboardData.files];
                  if (files.length > 0) {
                    e.preventDefault();
                    void attach(files);
                  }
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    void send();
                  }
                }}
                placeholder="Ask OpenCLI to do anything — paste or drop an image"
                rows={3}
              />

              <div className="composer-actions">
                <span className="menu-anchor">
                  <button
                    type="button"
                    className={`icon-button${attachMenu ? " on" : ""}`}
                    title="Add to this message"
                    onClick={() => setAttachMenu(!attachMenu)}
                  >
                    <PlusIcon />
                  </button>
                  <Popover open={attachMenu} onClose={() => setAttachMenu(false)}>
                    <AttachMenu
                      projects={projectList}
                      skills={skillList}
                      connectors={connectorList}
                      canAddFile={isDesktop()}
                      onAddImages={() => {
                        setAttachMenu(false);
                        imageInputRef.current?.click();
                      }}
                      onAddFile={() => {
                        setAttachMenu(false);
                        void chooseFiles().then((files) =>
                          setAttachments((prev) => [
                            ...prev,
                            ...files.map((file) => ({ kind: "file" as const, ...file })),
                          ]),
                        );
                      }}
                      onAddToProject={(target) => {
                        setAttachMenu(false);
                        const client = clientRef.current;
                        if (client?.threadId) {
                          void client
                            .attachThread(target.id, client.threadId)
                            .then(() => setProject(target))
                            .then(refreshThreads);
                        }
                      }}
                      onUseSkill={(skill) => {
                        setAttachMenu(false);
                        setAttachments((prev) => [
                          ...prev,
                          { kind: "skill", name: skill.name, path: skill.path },
                        ]);
                      }}
                      onManageSkills={() => {
                        setAttachMenu(false);
                        go("skills");
                      }}
                      onManageConnectors={() => {
                        setAttachMenu(false);
                        go("connectors");
                      }}
                    />
                  </Popover>
                </span>
                <input
                  ref={imageInputRef}
                  type="file"
                  accept="image/*"
                  multiple
                  hidden
                  onChange={(e) => {
                    void attach([...(e.target.files ?? [])]);
                    e.target.value = "";
                  }}
                />

                <span className="grow" />

                <span className="menu-anchor">
                  <button
                    type="button"
                    className={`model-button${modelMenu ? " on" : ""}`}
                    onClick={() => setModelMenu(!modelMenu)}
                    title="Model and effort"
                  >
                    <span>
                      {models.find((option) => option.model === model)?.displayName ?? "No model"}
                    </span>
                    {preferences.effort ? <em>{preferences.effort}</em> : null}
                    <ChevronIcon size={13} />
                  </button>
                  <Popover open={modelMenu} onClose={() => setModelMenu(false)} align="right">
                    <ModelMenu
                      models={models}
                      model={model}
                      effort={preferences.effort}
                      onPickModel={(next) => {
                        setModel(next);
                        modelRef.current = next;
                        setModelMenu(false);
                      }}
                      onPickEffort={(next) => {
                        setPreferences({ ...preferences, effort: next });
                        setModelMenu(false);
                      }}
                    />
                  </Popover>
                </span>

                {busy ? (
                  <button
                    type="button"
                    className="icon-button"
                    title="Stop"
                    onClick={() => void interrupt()}
                  >
                    <StopIcon />
                  </button>
                ) : null}
                <button
                  type="submit"
                  className="icon-button send"
                  title="Send"
                  disabled={busy || (!draft.trim() && attachments.length === 0)}
                >
                  <SendIcon />
                </button>
              </div>
            </form>

            {/* The reference keeps the working directory and the model out of
                the way down here, where they are visible without competing
                with the message being written. */}
            <div className="composer-foot">
              <button
                className="foot-button"
                title="Change the working directory"
                onClick={() => {
                  if (isDesktop()) {
                    void chooseDirectory(cwd).then((picked) => picked && setCwd(picked));
                  } else {
                    const picked = window.prompt("Working directory", cwd);
                    if (picked?.trim()) setCwd(picked.trim());
                  }
                }}
              >
                <FolderIcon size={13} />
                <span>{cwd || "."}</span>
              </button>
              <span className="grow" />
              {project ? <span className="foot-note">{project.name}</span> : null}
            </div>
            </div>
          </>
        )}
      </main>

      {detailsOpen ? (
        <aside className="details">
          <h3>This chat</h3>
          <dl>
            <dt>Directory</dt>
            <dd>{cwd || "."}</dd>
            <dt>Project</dt>
            <dd>{project?.name ?? "None"}</dd>
            <dt>Model</dt>
            <dd>{model || "default"}</dd>
            <dt>Approvals</dt>
            <dd>{preferences.approvalPolicy}</dd>
            <dt>Messages</dt>
            <dd>{items.length}</dd>
          </dl>

          <h3>Files changed</h3>
          {changes.length === 0 ? (
            <p className="muted">Nothing written yet.</p>
          ) : (
            <ul className="details-files">
              {[...new Set(changes.map((change) => change.path))].map((path) => (
                <li key={path} title={path}>
                  {path.split("/").pop()}
                </li>
              ))}
            </ul>
          )}
          {changes.length > 0 ? (
            <button className="link" onClick={() => go("artifacts")}>
              Open Artifacts
            </button>
          ) : null}
        </aside>
      ) : null}
    </div>
  );
}
