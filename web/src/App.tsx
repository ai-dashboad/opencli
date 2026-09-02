import { memo, useCallback, useEffect, useRef, useState } from "react";
import Sidebar, { type View } from "./Sidebar";
import {
  ApprovalChanges,
  ArtifactsView,
  ConnectorsView,
  CustomizeView,
  DispatchView,
  MemoryView,
  ModelsView,
  ProjectDetailView,
  ProjectsView,
  ScheduledView,
  SettingsView,
  PluginsView,
  SkillsView,
  ago,
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
  type PullProgress,
  type TokenUsage,
  type Run,
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
  BoltIcon,
  OpenCliMark,
  WorkingDot,
} from "./icons";
import { APPROVAL_MODES, ApprovalMenu, AttachMenu, ModelMenu, Popover } from "./menus";
import { Boot } from "./boot";
import { Markdown } from "./markdown";
import { shouldInterrupt, shouldSend } from "./composer";
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

/**
 * What Research adds to a thread.
 *
 * Instructions, not a retrieval pipeline: it changes how the agent is told to
 * work and is only as good as the tools it already has. Saying so here keeps
 * the claim honest at the one place it is made.
 */
function researchInstructions(preferences: Preferences): string {
  if (!preferences.research) return "";
  return [
    "Work in research mode for this conversation:",
    "- Gather evidence from several independent sources before concluding.",
    "- Say which source each claim rests on, and how you checked it.",
    "- State plainly what you could not verify rather than filling the gap.",
    "- Prefer reading the actual file, page or output over recalling it.",
  ].join("\n");
}

/**
 * What to head each item with.
 *
 * The agent's own prose gets nothing. It is most of a conversation, and
 * stamping the same name on every paragraph of it turns the transcript into a
 * column of one repeated word — which is what it looked like before commands
 * were rendered at all, because narration was the only thing left in it.
 */
const KIND_LABEL: Record<ThreadItem["kind"], string> = {
  user: "You",
  agent: "",
  command: "Ran a command",
  reasoning: "Thinking",
  fileChange: "Files",
  other: "",
  // Both are spans of a turn rather than things the agent produced, and both
  // are rendered on their own below.
  wait: "",
  total: "",
  compaction: "",
};

/**
 * The end of what is being thought, for a single line of it.
 *
 * The end rather than the beginning: a thought that has run for a minute is
 * somewhere quite else from where it started, and the interesting part is
 * where it is now. Whitespace is flattened because a line break in the middle
 * would take the row with it.
 */
function tailOf(text: string, room = 90): string {
  const flat = text.replace(/\s+/g, " ").trim();
  if (flat.length <= room) return flat;
  return `…${flat.slice(flat.length - room)}`;
}

/**
 * Elapsed time, in the largest unit that stays readable.
 *
 * Seconds alone stop meaning anything past a minute or two, which is exactly
 * the range a slow local model lands in.
 */
function formatElapsed(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}m ${String(seconds % 60).padStart(2, "0")}s`;
}

/**
 * How long something took, from milliseconds.
 *
 * Rounding to whole seconds made every command that finished in under half a
 * second read "0s", which is most of them — a figure that looked broken while
 * being technically true. Below a second it says milliseconds, and just above
 * it keeps one decimal, because 1.4s and 1.9s are different answers.
 */
function formatDuration(ms: number): string {
  if (ms < 1000) return `${Math.round(ms)}ms`;
  if (ms < 10_000) return `${(ms / 1000).toFixed(1)}s`;
  return formatElapsed(Math.round(ms / 1000));
}

/**
 * One row of the transcript, rendered only when its own contents change.
 *
 * The whole list used to re-render on every tick of the running clock — once a
 * second, a hundred and sixty articles reconciled and every Markdown reply
 * re-parsed, for the sake of one number changing. Memoised here so a tick
 * costs what it should: the rows that actually moved.
 */
const TranscriptItem = memo(function TranscriptItem({
  item,
  open,
  thinkingSince,
  onToggleThought,
}: {
  item: ThreadItem;
  open: boolean;
  /** When the thought began, for the one still being thought. */
  thinkingSince?: number;
  /**
   * Changes every second. Read by nothing, and that is the point: a thought
   * still being thought counts up, and it can only do that if the row is
   * allowed to re-render.
   */
  tick: number;
  onToggleThought: (id: string) => void;
}) {
  /*
   * A turn is not one span of time but several, and only some of them belong
   * to something the agent produced. Reading the conversation before it
   * answers, and the turn as a whole, are spans with nothing to show but
   * their length — so they are rows of their own rather than a label on
   * something else.
   */
  if (item.kind === "wait" || item.kind === "total" || item.kind === "compaction") {
    const said =
      item.kind === "wait"
        ? "Waited for the model"
        : item.kind === "total"
          ? "Turn total"
          : "Summarised the conversation";
    return (
      <article className={`item span ${item.kind}`}>
        <span className="label">
          <strong>{said}</strong>
          {item.durationMs !== undefined ? <em>{formatDuration(item.durationMs)}</em> : null}
        </span>
      </article>
    );
  }

  return (
    <article className={`item ${item.kind}`}>
      {item.kind === "reasoning" ? (
        <button type="button" className="label thought" onClick={() => onToggleThought(item.id)}>
          <strong>
            {item.durationMs !== undefined
              ? `Thought for ${formatDuration(item.durationMs)}`
              : "Thinking…"}
          </strong>
          {/*
            * While it thinks, the last of what it is thinking, on one line
            * beside the label. It is not kept: when the thought ends this
            * gives way to how long it took, and the words themselves are
            * behind "show" where they were all along. Watching a model think
            * is worth a line, not a wall.
            */}
          {item.durationMs === undefined ? (
            <span className="thought-peek">{tailOf(item.text)}</span>
          ) : null}
          {item.durationMs === undefined && thinkingSince ? (
            <em className="thought-clock">
              {formatElapsed(Math.max(0, Math.round((Date.now() - thinkingSince) / 1000)))}
            </em>
          ) : null}
          {item.text ? <em>{open ? "hide" : "show"}</em> : null}
        </button>
      ) : KIND_LABEL[item.kind] ? (
        <span className="label">
          <strong>{item.tool ?? KIND_LABEL[item.kind]}</strong>
          {item.summary ? <span className="what">{item.summary}</span> : null}
          {item.durationMs !== undefined ? <em>{formatDuration(item.durationMs)}</em> : null}
        </span>
      ) : null}
      {/*
        * The agent's prose is Markdown; a command is not. What ran and what it
        * printed are shown exactly as they are, because a shell line with an
        * asterisk in it means the asterisk.
        */}
      {item.kind === "reasoning" && !open ? null : item.kind === "agent" ||
        item.kind === "reasoning" ? (
        <Markdown text={item.text} />
      ) : (
        <pre>{item.text}</pre>
      )}
      {item.output ? <pre className="output">{item.output}</pre> : null}
      {item.exitCode !== undefined && item.exitCode !== 0 ? (
        <span className="exit">exit {item.exitCode}</span>
      ) : null}
    </article>
  );
});

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
  const [runs, setRuns] = useState<Run[]>([]);
  // Downloads in flight, kept in the shell so progress survives leaving the
  // Models panel — a download takes minutes and the user will look elsewhere.
  const [pulls, setPulls] = useState<Record<string, PullProgress>>({});
  const [usage, setUsage] = useState<TokenUsage | null>(null);
  /** Seconds the current turn has been running, ticking while it does. */
  const [elapsed, setElapsed] = useState(0);
  /** Characters written so far in this turn, for a live sense of progress. */
  const [streamed, setStreamed] = useState(0);
  // Cowork sends work to the background instead of waiting on it inline.
  const [cowork, setCowork] = useState(false);
  const [showAllRuns, setShowAllRuns] = useState(false);
  // The project whose page is being read, which is not necessarily the one the
  // current chat belongs to.
  const [viewing, setViewing] = useState<Project | null>(null);
  const [modelMenu, setModelMenu] = useState(false);
  const [modeMenu, setModeMenu] = useState(false);
  /** Which pieces of thinking the reader asked to see. */
  const [openThoughts, setOpenThoughts] = useState<Record<string, boolean>>({});
  const [activeThreadId, setActiveThreadId] = useState<string | null>(null);
  const [models, setModels] = useState<ModelOption[]>([]);
  const [model, setModel] = useState<string>("");

  const [project, setProject] = useState<Project | null>(null);
  const [changes, setChanges] = useState<FileChange[]>([]);
  const [preferences, setPreferences] = useState<Preferences>({ approvalPolicy: "untrusted" });
  const [approval, setApproval] = useState<ApprovalRequest | null>(null);
  const [error, setError] = useState<string | null>(null);
  /**
   * The attempt being retried, while a turn is still alive.
   *
   * A request that fails and is retried eight times took eighteen minutes on
   * this machine, and the screen said "Waiting for the model…" for all of it.
   */
  const [retry, setRetry] = useState<{ attempt: string; reason: string } | null>(null);
  /** What the agent is doing that is not answering — compacting, mostly. */
  const [notice, setNotice] = useState<{
    text: string;
    progress?: { done: number; total: number };
  } | null>(null);
  /** True while the conversation is being summarised rather than answered. */
  const [compacting, setCompacting] = useState(false);
  const [draft, setDraft] = useState("");
  const [attachments, setAttachments] = useState<Attachment[]>([]);
  /**
   * The chat a turn is running in, or null when nothing is running.
   *
   * A single flag leaked across chats: a turn started in one and then switched
   * away from left every other conversation claiming to be working, because
   * there is one agent and the flag did not say which chat it belonged to.
   */
  const [runningIn, setRunningIn] = useState<string | null>(null);
  /** When the running turn began, so its clock is its own. */
  const [turnAt, setTurnAt] = useState<number | null>(null);
  /**
   * When each piece of thinking started, by item id.
   *
   * The server sends no duration for reasoning, so it is measured here: the
   * row counts up while it streams and keeps its total when it ends. Without
   * it a model could think for four minutes behind a row that never changed
   * and never said how long it had taken.
   */
  const thoughtSince = useRef<Record<string, number>>({});

  const clientRef = useRef<OpenCliClient | null>(null);
  const modelRef = useRef<string>("");
  // Skills are listed per directory, and this refresh runs from callbacks
  // created before the directory is known.
  const cwdRef = useRef<string>("");
  // `cloneRepo` opens the project it just made, but is defined above it.
  const openProjectRef = useRef<((project: Project) => Promise<void>) | null>(null);
  // Same reason as the model: `connectTo` is created before the user has had a
  // chance to change anything, so closing over the state would pin every
  // thread to the initial preferences.
  const preferencesRef = useRef<Preferences>(preferences);
  const transcriptRef = useRef<HTMLDivElement>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);

  /*
   * Opening a conversation lands at the end of it.
   *
   * After the browser has laid the transcript out, not before: a single
   * scroll on the render that sets the items happens while the height is
   * still whatever fitted so far, so it stopped somewhere in the middle of a
   * long chat. Two frames — one for the layout, one for anything that settled
   * during it.
   */
  useEffect(() => {
    let second = 0;
    const first = requestAnimationFrame(() => {
      const box = transcriptRef.current;
      if (box) box.scrollTop = box.scrollHeight;
      second = requestAnimationFrame(() => {
        const settled = transcriptRef.current;
        if (settled) settled.scrollTop = settled.scrollHeight;
      });
    });
    return () => {
      cancelAnimationFrame(first);
      cancelAnimationFrame(second);
    };
  }, [activeThreadId]);

  /*
   * A conversation being written follows itself, unless it is being read.
   *
   * Someone who has scrolled up to look at what happened earlier is not
   * asking to be dragged back down every time a word arrives.
   */
  useEffect(() => {
    const box = transcriptRef.current;
    if (!box) return;
    const room = box.scrollHeight - box.scrollTop - box.clientHeight;
    if (room > 160) return;
    requestAnimationFrame(() => {
      const settled = transcriptRef.current;
      if (settled) settled.scrollTop = settled.scrollHeight;
    });
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

  // ⌘U opens the file picker, the shortcut the reference shows next to
  // "Add files or photos".
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      // `key` is absent for some input-method events, and throwing here on
      // every keystroke would fill the console during ordinary typing.
      if ((event.metaKey || event.ctrlKey) && event.key?.toLowerCase() === "u") {
        event.preventDefault();
        imageInputRef.current?.click();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  /** Refresh the sidebar; failures here must not break the chat. */
  const refreshThreads = useCallback(async () => {
    const client = clientRef.current;
    if (!client) return;
    // Each list decorates the sidebar independently, so one failing should not
    // blank the others.
    const [listed, projects, tasks, skills, connectors, recent] = await Promise.all([
      client.listThreads().catch(() => null),
      client.listProjects().catch(() => null),
      client.listTasks().catch(() => null),
      client.listSkills(cwdRef.current || ".").catch(() => null),
      client.listConnectors().catch(() => null),
      client.listRuns({ limit: 30 }).catch(() => null),
    ]);
    if (listed) setThreads(listed);
    if (projects) setProjectList(projects);
    if (tasks) setTaskList(tasks);
    if (skills) setSkillList(skills);
    if (connectors) setConnectorList(connectors);
    if (recent) setRuns(recent);
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
        instructions: [instructions, remembered, researchInstructions(preferencesRef.current)]
          .filter(Boolean)
          .join("\n\n"),
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
  /**
   * Drop everything that belonged to the conversation being left.
   *
   * There is one agent and one screen, so anything not cleared here follows
   * the reader into the next chat: a half-typed message, an error, a token
   * total from somewhere else. The approval box is worse than untidy — it
   * would offer a command from another conversation to someone who cannot see
   * what led to it, which is why it also carries the thread that raised it.
   */
  const forgetThisChat = useCallback(() => {
    setItems([]);
    setChanges([]);
    setUsage(null);
    setApproval(null);
    setError(null);
    setDraft("");
    setAttachments([]);
    setOpenThoughts({});
  }, []);

  const startFreshThread = useCallback(
    async (directory: string, instructions?: string, projectId: string | null = null) => {
      const client = clientRef.current;
      if (!client) return null;
      forgetThisChat();
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
        onItem: (arrived) => {
          // Reasoning carries no duration of its own, so the one measured here
          // is attached as it finishes.
          const startedAt = thoughtSince.current[arrived.id];
          const item =
            arrived.kind === "reasoning" && arrived.durationMs === undefined && startedAt
              ? { ...arrived, durationMs: Date.now() - startedAt }
              : arrived;
          delete thoughtSince.current[arrived.id];

          // A finished item replaces the partial one it was streamed as,
          // rather than appearing beside it.
          setItems((prev) => {
            const at = prev.findIndex((other) => other.id === item.id);
            if (at === -1) return [...prev, item];
            const next = [...prev];
            next[at] = item;
            return next;
          });
          if (item.changes?.length) {
            setChanges((prev) => [...prev, ...item.changes!]);
          }
        },
        onItemDelta: (item) => {
          // Thinking can be turned off, but it still counts as progress: the
          // working line says something is happening even when it is hidden.
          setStreamed(item.text.length);
          if (item.kind === "reasoning" && !thoughtSince.current[item.id]) {
            thoughtSince.current[item.id] = Date.now();
          }
          if (item.kind === "reasoning" && preferencesRef.current.showThinking === false) return;
          setItems((prev) => {
            const at = prev.findIndex((other) => other.id === item.id);
            if (at === -1) return [...prev, item];
            const next = [...prev];
            next[at] = { ...next[at], text: item.text };
            return next;
          });
        },
        onTurnStart: (threadId) => {
          // The turn's own clock, restarted by the event that begins it. A
          // turn the agent starts for itself gets one too.
          setRunningIn(threadId);
          setTurnAt(Date.now());
          setStreamed(0);
          setRetry(null);
          setNotice(null);
          setCompacting(false);
          // Whatever went wrong last time is over. Nothing cleared this, so a
          // failure stayed on screen through every later prompt, saying a turn
          // that had since succeeded had failed.
          setError(null);
        },
        onTurnComplete: () => {
          setRunningIn(null);
          setRetry(null);
          setNotice(null);
          void refreshThreads();
        },
        onError: (message) => {
          setError(message);
          setRetry(null);
          setNotice(null);
          setRunningIn(null);
        },
        onRetry: (attempt, reason) => setRetry({ attempt, reason }),
        onNotice: (text, progress) => setNotice({ text, progress }),
        onCompacting: (on) => {
          setCompacting(on);
          if (!on) setNotice(null);
        },
        onApprovalRequest: setApproval,
        onTokenUsage: setUsage,
        onPullProgress: (progress) =>
          setPulls((prev) => ({
            ...prev,
            [progress.model]: { ...prev[progress.model], ...progress },
          })),
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

  /*
   * Count while the agent works.
   *
   * A local model can take minutes for one reply, and a spinner that says
   * only "Working…" cannot be told apart from one that has hung. The number
   * is what makes waiting bearable and a stall obvious.
   */
  // Only the conversation a turn belongs to is working; the clock, though,
  // follows the turn, so switching away and back does not restart it.
  const busy = runningIn !== null && runningIn === activeThreadId;

  useEffect(() => {
    if (!runningIn || turnAt === null) return;
    setElapsed(Math.round((Date.now() - turnAt) / 1000));
    const timer = setInterval(() => setElapsed(Math.round((Date.now() - turnAt) / 1000)), 1000);
    return () => clearInterval(timer);
    // Keyed on the moment the turn began: a second turn in the same chat
    // leaves `runningIn` unchanged, so keying on that never restarted it.
  }, [runningIn, turnAt]);

  /*
   * What is happening, rather than that something is.
   *
   * The last item in the transcript says it: a command that has not finished
   * is being run, thinking that has not finished is being thought. "Working…"
   * for four minutes tells a reader nothing they could not see.
   */
  const doing = (() => {
    // Summarising is not writing, and saying "Writing…" through a minute of
    // it was the wrong word for the longest part of the turn.
    if (compacting) return "Summarising the conversation…";
    const last = items[items.length - 1];
    if (!last) return "Waiting for the model…";
    if (last.kind === "command") return `${last.summary ?? "Running a command"}…`;
    if (last.kind === "reasoning") return "Thinking…";
    // Nothing has come back yet when the last thing in the transcript is what
    // the reader just typed. That window is the model reading the
    // conversation, not writing an answer, and it is the longest wait in a
    // turn — saying "Writing…" through all of it was simply untrue.
    if (last.kind === "user") return "Waiting for the model…";
    return "Writing…";
  })();

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

  /**
   * Send one prompt on the open thread.
   *
   * Separate from the composer so a prompt can come from somewhere else — the
   * project page starts a chat with its first message already typed.
   */
  const sendPrompt = useCallback(
    async (text: string, sending: Attachment[]) => {
      const client = clientRef.current;
      if ((!text && sending.length === 0) || !client) return;

      // Cowork sends the work away rather than waiting on it: the run appears in
      // the Active list and keeps going after this window moves on. Attachments
      // are not carried — a background run has no conversation to attach them to.
      if (cowork) {
        try {
          await client.dispatchRun({
            prompt: text,
            cwd: cwd || ".",
            ...(modelRef.current ? { model: modelRef.current } : {}),
            source: "cowork",
          });
          void refreshThreads();
        } catch (err) {
          setError(err instanceof Error ? err.message : String(err));
        }
        return;
      }

      setRunningIn(client.threadId ?? null);
      setTurnAt(Date.now());
      // Cleared here as well as on `turn/started`: a turn that fails before the
      // server acknowledges it never sends that event, and the previous error
      // would sit there through the failure of the next one.
      setError(null);
      // The server echoes the user message back as a thread item, so do not add
      // it locally — doing so showed every prompt twice.
      try {
        await client.send(text, {
          effort: preferencesRef.current.effort,
          attachments: sending,
          // Sent every turn so switching model mid-conversation takes effect.
          // Read from the ref for the same reason the thread does: this callback
          // outlives the render that created it.
          ...(modelRef.current ? { model: modelRef.current } : {}),
          ...(preferencesRef.current.approvalPolicy
            ? { approvalPolicy: preferencesRef.current.approvalPolicy }
            : {}),
          // Defaulting to on keeps the agent's reasoning visible unless the user
          // asks for quiet.
          summary: preferencesRef.current.showThinking === false ? "none" : "auto",
        });
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        setRunningIn(null);
      }
    },
    [cowork, cwd, refreshThreads],
  );

  const send = useCallback(async () => {
    const text = draft.trim();
    if ((!text && attachments.length === 0) || !clientRef.current) return;
    const sending = attachments;
    setDraft("");
    setAttachments([]);
    await sendPrompt(text, sending);
  }, [attachments, draft, sendPrompt]);

  const interrupt = useCallback(async () => {
    try {
      await clientRef.current?.interrupt();
    } catch {
      // The turn may have finished between render and click.
    }
    setRunningIn(null);
  }, []);

  /*
   * Escape stops the turn, wherever the focus happens to be.
   *
   * Reaching for the mouse to hit a five-pixel "stop" is the wrong shape for
   * the one action taken in a hurry — usually on realising the prompt was
   * wrong, seconds after sending it.
   */
  useEffect(() => {
    if (!busy) return;
    const onKey = (event: KeyboardEvent) => {
      if (!shouldInterrupt(event)) return;
      event.preventDefault();
      void interrupt();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [busy, interrupt]);

  const toggleThought = useCallback((id: string) => {
    setOpenThoughts((prev) => ({ ...prev, [id]: !prev[id] }));
  }, []);

  const openThread = useCallback(
    async (id: string) => {
      const client = clientRef.current;
      if (!client) return;
      go("chat");
      forgetThisChat();
      // Which project this chat is in is a property of the chat, so opening one
      // has to move with it. It did not, and the app went on claiming the last
      // project opened by hand — the sidebar marked that one as the place you
      // were, while the chat on screen belonged to another.
      const owner = projectList.find((row) => row.threadIds.includes(id)) ?? null;
      setProject(owner);
      if (owner) setCwd(owner.cwd);
      try {
        setItems(await client.resumeThread(id));
        setActiveThreadId(id);
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
    },
    [projectList],
  );

  /**
   * Show a project's page.
   *
   * Starting a chat immediately, as this used to, made the description, the
   * instructions and the existing conversations unreachable.
   */
  const showProject = useCallback(
    (target: Project) => {
      setViewing(target);
      go("project");
    },
    [go],
  );

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

  useEffect(() => {
    openProjectRef.current = openProject;
  }, [openProject]);

  /**
   * Start a chat in a project with its first message already written.
   *
   * The project page has its own composer, so getting from "here is my project"
   * to "here is what I want" is one step rather than three.
   */
  const startChatIn = useCallback(
    async (target: Project, text: string) => {
      await openProject(target);
      await sendPrompt(text.trim(), []);
    },
    [openProject, sendPrompt],
  );

  /**
   * Clone a repository and open it as a project.
   *
   * The clone alone would leave a directory nobody is pointed at, so the
   * project is created in the same step and the chat moves into it.
   */
  const cloneRepo = useCallback(async () => {
    const client = clientRef.current;
    if (!client) return;
    const url = window.prompt("Repository URL", "https://github.com/");
    if (!url?.trim()) return;
    const into = isDesktop()
      ? await chooseDirectory(cwd)
      : window.prompt("Clone into which directory?", cwd);
    if (!into?.trim()) return;

    setError(null);
    try {
      const cloned = await client.cloneRepository(url.trim(), into.trim());
      const created = await client.createProject({
        name: cloned.name,
        cwd: cloned.path,
        instructions: "",
      });
      await refreshThreads();
      await openProjectRef.current?.(created);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [cwd, refreshThreads]);

  /**
   * Turn what this chat did into a skill.
   *
   * The transcript is raw material, not the product: a skill is a short set of
   * instructions for next time, so what is written is the agent's own summary
   * of its steps — shown for the user to edit before it is saved, because a
   * skill nobody read is one nobody can trust.
   */
  const recordSkill = useCallback(async () => {
    const client = clientRef.current;
    if (!client) return;
    if (items.length === 0) {
      setError("There is nothing to record yet — have the chat do something first.");
      return;
    }

    const name = window.prompt("Name this skill (letters, digits, - and _)");
    if (!name?.trim()) return;
    const description = window.prompt(
      "When should the agent use it? This is what decides whether it is loaded.",
    );
    if (!description?.trim()) return;

    // Draw the steps from what actually happened rather than asking the model
    // to recall them, so the skill matches the run it came from.
    const steps = items
      .filter((item) => item.kind === "command" || item.kind === "fileChange")
      .map((item) => `- ${item.text.split("\n")[0]}`)
      .slice(0, 30);
    const draft = [
      "## Steps",
      steps.length > 0 ? steps.join("\n") : "- (describe the steps here)",
      "",
      "## Notes",
      `Recorded from a chat in ${cwd || "."}.`,
    ].join("\n");

    const body = window.prompt("Edit the steps before saving:", draft);
    if (!body?.trim()) return;

    try {
      const saved = await client.recordSkill({
        name: name.trim(),
        description: description.trim(),
        body: body.trim(),
      });
      setError(null);
      await refreshThreads();
      window.alert(`Saved ${saved.name}. It is available in new chats.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [cwd, items, refreshThreads]);

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
    return <Boot failed={status === "error"} detail={error} />;
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
        runningThreadId={runningIn}
        activeProjectId={project?.id ?? null}
        viewedProjectId={view === "project" ? (viewing?.id ?? null) : null}
        onNavigate={go}
        onNewChat={() => void newChat()}
        onOpenThread={(id) => void openThread(id)}
        onOpenProject={showProject}
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

        {view === "dispatch" && client ? (
          <DispatchView client={client} cwd={cwd || "."} model={model} />
        ) : view === "customize" ? (
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
            onOpen={showProject}
            // The sidebar reads its own copy of the list, so a project created
            // here was invisible there until something else happened to refresh.
            onChanged={refreshThreads}
            onBrowse={isDesktop() ? chooseDirectory : undefined}
          />
        ) : view === "scheduled" && client ? (
          <ScheduledView client={client} cwd={cwd || "."} />
        ) : view === "skills" && client ? (
          <SkillsView client={client} cwd={cwd || "."} />
        ) : view === "connectors" && client ? (
          <ConnectorsView client={client} />
        ) : view === "project" && client && viewing ? (
          <ProjectDetailView
            client={client}
            project={viewing}
            threads={threads}
            onNewChat={() => void openProject(viewing)}
            onStartChat={(text) => void startChatIn(viewing, text)}
            // `openThread` settles the project and the directory itself, from
            // whichever project owns the chat.
            onOpenThread={(id) => void openThread(id)}
            onChanged={() => {
              void refreshThreads();
              void client.listProjects().then((rows) => {
                const fresh = rows.find((row) => row.id === viewing.id);
                if (fresh) setViewing(fresh);
              });
            }}
            onBack={() => go("projects")}
          />
        ) : view === "models" && client ? (
          <ModelsView
            client={client}
            pulls={pulls}
            onPull={(target, model) => {
              // Show the row immediately; the first progress event may be
              // seconds away while the manifest is fetched.
              setPulls((prev) => ({
                ...prev,
                [model]: { model, baseUrl: target, status: "starting" },
              }));
              void client.pullModel(target, model).catch((err: unknown) =>
                setPulls((prev) => ({
                  ...prev,
                  [model]: {
                    model,
                    baseUrl: target,
                    error: err instanceof Error ? err.message : String(err),
                  },
                })),
              );
            }}
          />
        ) : view === "plugins" && client ? (
          <PluginsView client={client} />
        ) : view === "settings" && client ? (
          <SettingsView client={client} />
        ) : (
          <>
            <div className="transcript" ref={transcriptRef}>
              <div className={`thread${items.length === 0 ? " empty" : ""}`}>
                {items.length === 0 ? (
                  <div className="landing">
                    <h1>
                      <OpenCliMark size={30} />
                      <span>Ready when you are</span>
                    </h1>
                    {runs.length > 0 ? (
                      <section className="recent">
                        <div className="recent-head">
                          <span>Active</span>
                          <button
                            className="link"
                            onClick={() => {
                              void clientRef.current?.clearRuns().then(refreshThreads);
                            }}
                          >
                            Clear active
                          </button>
                        </div>
                        <ul>
                          {runs.slice(0, showAllRuns ? 20 : 5).map((run) => (
                            <li key={run.id}>
                              <span className="run-icon">
                                <ClockIcon size={15} />
                                <i className={`run-dot ${run.status}`} />
                              </span>
                              <button
                                className="what"
                                onClick={() => go("dispatch")}
                                title={run.prompt}
                              >
                                <strong>{run.title}</strong>
                                <em>{ago(run.finishedAt ?? run.startedAt)}</em>
                              </button>
                            </li>
                          ))}
                        </ul>
                        {runs.length > 5 ? (
                          <button className="link more" onClick={() => setShowAllRuns(!showAllRuns)}>
                            {showAllRuns ? "Show less" : "Show more"}
                          </button>
                        ) : null}
                      </section>
                    ) : null}
                  </div>
                ) : null}
                {items.map((item) => {
                  // Only the thought still being thought is given the ticking
                  // clock. Handing it to every row would change a prop on all
                  // of them once a second and undo the memo completely, which
                  // is the whole thing being fixed.
                  const counting =
                    item.kind === "reasoning" &&
                    item.durationMs === undefined &&
                    thoughtSince.current[item.id] !== undefined;
                  return (
                    <TranscriptItem
                      key={item.id}
                      item={item}
                      open={!!openThoughts[item.id]}
                      thinkingSince={thoughtSince.current[item.id]}
                      tick={counting ? elapsed : 0}
                      onToggleThought={toggleThought}
                    />
                  );
                })}
                {busy ? (
                  <div className="working-block">
                    <p className="working">
                      <WorkingDot />
                      <span className="doing">
                        {doing} {formatElapsed(elapsed)}
                        {streamed > 0 ? ` · ~${Math.round(streamed / 4)} written` : ""}
                      </span>
                      {retry ? (
                        <span className="retrying" title={retry.reason}>
                          {retry.attempt}
                        </span>
                      ) : null}
                      {/*
                        * One control, naming its own shortcut. Sat next to the
                        * text rather than pushed to the far right, because the
                        * transcript runs the full width of the window and
                        * right-aligning would strand it a screen away from the
                        * words it belongs to.
                        */}
                      <button type="button" className="stop-button" onClick={() => void interrupt()}>
                        <StopIcon size={12} />
                        Stop
                        <kbd>esc</kbd>
                      </button>
                    </p>
                    {/*
                      * How far along, under the line that says what is going
                      * on rather than crammed into it. Only while something
                      * long enough to have steps is running, so the composer
                      * does not shift for every turn.
                      */}
                    {notice ? (
                      <p className="working-step">
                        {/*
                          * A bar only where there is something real to
                          * measure. The steps are counted by the agent as it
                          * cuts a long conversation up, so this one is honest;
                          * a note without a count gets the words alone rather
                          * than a bar moving at an invented rate.
                          */}
                        {notice.progress ? (
                          <span
                            className="progress"
                            role="progressbar"
                            aria-valuenow={notice.progress.done}
                            aria-valuemin={0}
                            aria-valuemax={notice.progress.total}
                          >
                            <span
                              className="progress-fill"
                              style={{
                                width: `${Math.min(100, Math.round((notice.progress.done / notice.progress.total) * 100))}%`,
                              }}
                            />
                          </span>
                        ) : null}
                        {notice.text}
                      </p>
                    ) : null}
                  </div>
                ) : null}
                {!busy && usage && usage.total > 0 ? (
                  <p className="spent">
                    {usage.last > 0
                      ? `${usage.last.toLocaleString()} tokens this turn${
                          usage.output > 0 ? ` (${usage.output.toLocaleString()} written)` : ""
                        } · `
                      : ""}
                    {usage.total.toLocaleString()} in this chat
                    {/*
                      * The window is stated, not compared against.
                      *
                      * The total is everything this conversation has spent,
                      * across however many compactions; the window is what
                      * fits in one request. Dividing one by the other produced
                      * "616% of the 94K context", which is not a fact about
                      * anything — a conversation cannot be six times its own
                      * context, and the number read as an error.
                      */}
                    {usage.contextWindow
                      ? ` · ${Math.round(usage.contextWindow / 1024)}K context`
                      : ""}
                  </p>
                ) : null}
              </div>
            </div>

            {approval && (!approval.threadId || approval.threadId === activeThreadId) ? (
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
                  if (!shouldSend({ ...e, isComposing: e.nativeEvent.isComposing })) return;
                  e.preventDefault();
                  void send();
                }}
                placeholder={
                  cowork
                    ? "Describe the work; it will run on its own"
                    : "Ask OpenCLI to do anything — paste or drop an image"
                }
                rows={3}
              />

              {/*
                * Below what is being typed, not above it.
                *
                * Pasting an image mid-sentence pushed the words already
                * written down the screen and the caret with them, so the
                * thing you were in the middle of saying moved while you were
                * saying it. It belongs after the text, where it was added.
                */}
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
                      onRecordSkill={() => {
                        setAttachMenu(false);
                        void recordSkill();
                      }}
                      onManageConnectors={() => {
                        setAttachMenu(false);
                        go("connectors");
                      }}
                      onBrowsePlugins={() => {
                        setAttachMenu(false);
                        go("plugins");
                      }}
                      onCloneRepo={() => {
                        setAttachMenu(false);
                        void cloneRepo();
                      }}
                      webSearch={preferences.webSearch ?? false}
                      research={preferences.research ?? false}
                      onToggleWebSearch={(on) =>
                        setPreferences({ ...preferences, webSearch: on })
                      }
                      onToggleResearch={(on) => setPreferences({ ...preferences, research: on })}
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

                <span className="mode-toggle" role="group" aria-label="Send mode">
                  <button
                    type="button"
                    className={cowork ? "" : "on"}
                    onClick={() => setCowork(false)}
                    title="Answer here, now"
                  >
                    Chat
                  </button>
                  <button
                    type="button"
                    className={cowork ? "on" : ""}
                    onClick={() => setCowork(true)}
                    title="Send it off to run on its own"
                  >
                    Cowork
                  </button>
                </span>

                <span className="grow" />

                <span className="menu-anchor">
                  <button
                    type="button"
                    className={`model-button${modeMenu ? " on" : ""}`}
                    onClick={() => setModeMenu(!modeMenu)}
                    title="When the agent stops to ask"
                  >
                    <BoltIcon size={13} />
                    <span>
                      {APPROVAL_MODES.find(
                        (mode) => mode.value === (preferences.approvalPolicy ?? "untrusted"),
                      )?.label ?? "Manual"}
                    </span>
                    <ChevronIcon size={13} />
                  </button>
                  <Popover open={modeMenu} onClose={() => setModeMenu(false)} align="right" wide>
                    <ApprovalMenu
                      policy={preferences.approvalPolicy ?? "untrusted"}
                      onPick={(next) => {
                        setPreferences({ ...preferences, approvalPolicy: next });
                        setModeMenu(false);
                      }}
                    />
                  </Popover>
                </span>

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
                  <Popover open={modelMenu} onClose={() => setModelMenu(false)} align="right" wide>
                    <ModelMenu
                      models={models}
                      model={model}
                      effort={preferences.effort}
                      showThinking={preferences.showThinking ?? true}
                      onToggleThinking={(on) =>
                        setPreferences({ ...preferences, showThinking: on })
                      }
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
