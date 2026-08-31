import { useCallback, useEffect, useState } from "react";
import { FolderIcon, FolderPlusIcon, PinIcon, SearchIcon } from "./icons";
import { Dialog } from "./menus";
import type {
  ApprovalPolicy,
  ConnectorConfig,
  ConnectorOffer,
  ConnectorSummary,
  FileChange,
  InstalledPlugin,
  Memory,
  OpenCliClient,
  Personality,
  Preferences,
  ReasoningEffort,
  PluginOffer,
  Project,
  Run,
  RunStatus,
  ScheduledTask,
  SkillSummary,
} from "./protocol";

/**
 * Shared loader for the read-only panels.
 *
 * Each panel shows the same three states — loading, failed, empty — and getting
 * those wrong is what makes a panel look broken rather than simply empty.
 */
function useRemote<T>(load: () => Promise<T[]>, deps: unknown[]): {
  rows: T[];
  error: string | null;
  loading: boolean;
} {
  const [rows, setRows] = useState<T[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    load()
      .then((data) => {
        if (!cancelled) setRows(data);
      })
      .catch((err: unknown) => {
        if (!cancelled) setError(err instanceof Error ? err.message : String(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return { rows, error, loading };
}

function Panel({
  title,
  subtitle,
  loading,
  error,
  empty,
  children,
}: {
  title: string;
  subtitle: string;
  loading: boolean;
  error: string | null;
  empty: boolean;
  children: React.ReactNode;
}) {
  return (
    <section className="panel">
      <h2>{title}</h2>
      <p className="hint">{subtitle}</p>
      {loading ? <p className="muted">Loading…</p> : null}
      {error ? <p className="error">{error}</p> : null}
      {!loading && !error && empty ? <p className="muted">Nothing configured.</p> : null}
      {children}
    </section>
  );
}

export function SkillsView({ client, cwd }: { client: OpenCliClient; cwd: string }) {
  const { rows, error, loading } = useRemote<SkillSummary>(
    () => client.listSkills(cwd),
    [client, cwd],
  );

  return (
    <Panel
      title="Skills"
      subtitle={`Reusable capabilities available in ${cwd}`}
      loading={loading}
      error={error}
      empty={rows.length === 0}
    >
      <ul className="rows">
        {rows.map((skill) => (
          <li key={skill.name}>
            <strong>{skill.name}</strong>
            <span>{skill.description}</span>
          </li>
        ))}
      </ul>
    </Panel>
  );
}

/**
 * Connectors: the MCP servers this machine will start.
 *
 * Two lists in one: what is configured, and what can be added by name.
 * Changes are written to `config.toml`, and servers start with a session — so
 * a change applies to the next chat, which the panel says rather than leaving
 * the user to wonder why nothing happened.
 */
export function ConnectorsView({ client }: { client: OpenCliClient }) {
  const [configured, setConfigured] = useState<ConnectorConfig[]>([]);
  const [offers, setOffers] = useState<ConnectorOffer[]>([]);
  const [status, setStatus] = useState<ConnectorSummary[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState({ name: "", kind: "stdio", command: "", url: "" });

  const reload = useCallback(async () => {
    try {
      const [rows, catalogued, live] = await Promise.all([
        client.listConnectorConfigs(),
        client.connectorCatalog(),
        client.listConnectors().catch(() => []),
      ]);
      setConfigured(rows);
      setOffers(catalogued);
      setStatus(live);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const run = useCallback(
    async (work: Promise<unknown>) => {
      try {
        await work;
        await reload();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
    },
    [reload],
  );

  const addManual = useCallback(() => {
    const transport =
      draft.kind === "http"
        ? { kind: "http" as const, url: draft.url.trim() }
        : {
            kind: "stdio" as const,
            command: draft.command.trim().split(/\s+/)[0] ?? "",
            args: draft.command.trim().split(/\s+/).slice(1),
          };
    void run(
      client.addConnector({ name: draft.name.trim(), transport }).then(() => {
        setAdding(false);
        setDraft({ name: "", kind: "stdio", command: "", url: "" });
      }),
    );
  }, [client, draft, run]);

  const notYetAdded = offers.filter(
    (offer) => !configured.some((row) => row.name === offer.id || row.name === offer.name),
  );

  return (
    <section className="panel">
      <h2>Connectors</h2>
      <p className="hint">
        MCP servers the agent can call tools through. Servers start with a chat, so a change here
        applies to the next one you open.
      </p>
      {error ? <p className="error">{error}</p> : null}

      <h3>Configured</h3>
      <ul className="rows">
        {configured.length === 0 ? <li className="muted">None yet.</li> : null}
        {configured.map((row) => {
          const live = status.find((entry) => entry.name === row.name);
          return (
            <li key={row.name}>
              <strong>{row.name}</strong>
              <span>
                {row.transport.kind === "http"
                  ? row.transport.url
                  : [row.transport.command, ...(row.transport.args ?? [])].join(" ")}
              </span>
              {live ? (
                <span>
                  {live.toolCount} tool{live.toolCount === 1 ? "" : "s"} · {live.status}
                </span>
              ) : null}
              <div className="actions">
                <label className="scope">
                  <input
                    type="checkbox"
                    checked={row.enabled}
                    onChange={(e) => void run(client.setConnectorEnabled(row.name, e.target.checked))}
                  />
                  Enabled
                </label>
                <button className="secondary" onClick={() => void run(client.removeConnector(row.name))}>
                  Remove
                </button>
              </div>
            </li>
          );
        })}
      </ul>

      <h3>Add a connector</h3>
      <ul className="rows">
        {notYetAdded.map((offer) => (
          <li key={offer.id}>
            <strong>{offer.name}</strong>
            <span>{offer.description}</span>
            {offer.note ? <span>{offer.note}</span> : null}
            <div className="actions">
              <button
                onClick={() =>
                  void run(client.addConnector({ name: offer.id, transport: offer.transport }))
                }
              >
                Add
              </button>
            </div>
          </li>
        ))}
      </ul>

      {adding ? (
        <div className="project-form">
          <input
            value={draft.name}
            onChange={(e) => setDraft({ ...draft, name: e.target.value })}
            placeholder="Name (letters, digits, - and _)"
          />
          <div className="choices">
            {(["stdio", "http"] as const).map((kind) => (
              <label key={kind} className="choice">
                <input
                  type="radio"
                  name="transport"
                  checked={draft.kind === kind}
                  onChange={() => setDraft({ ...draft, kind })}
                />
                <span>
                  <strong>{kind === "stdio" ? "Local command" : "HTTP server"}</strong>
                  <span className="hint">
                    {kind === "stdio"
                      ? "A program on this machine, started by OpenCLI."
                      : "A server reachable over HTTP."}
                  </span>
                </span>
              </label>
            ))}
          </div>
          {draft.kind === "stdio" ? (
            <input
              value={draft.command}
              onChange={(e) => setDraft({ ...draft, command: e.target.value })}
              placeholder="npx -y @modelcontextprotocol/server-github"
            />
          ) : (
            <input
              value={draft.url}
              onChange={(e) => setDraft({ ...draft, url: e.target.value })}
              placeholder="https://example.com/mcp"
            />
          )}
          <div className="actions">
            <button
              onClick={addManual}
              disabled={
                !draft.name.trim() ||
                (draft.kind === "stdio" ? !draft.command.trim() : !draft.url.trim())
              }
            >
              Add
            </button>
            <button className="secondary" onClick={() => setAdding(false)}>
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <button className="secondary" onClick={() => setAdding(true)}>
          Add another…
        </button>
      )}
    </section>
  );
}

/** Flatten nested config into `a.b.c` paths, matching how origins are keyed. */
function flatten(value: unknown, prefix = ""): [string, unknown][] {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return prefix ? [[prefix, value]] : [];
  }
  return Object.entries(value as Record<string, unknown>).flatMap(([key, nested]) =>
    flatten(nested, prefix ? `${prefix}.${key}` : key),
  );
}

/** The file a value came from, if the server reported one. */
function originFile(origins: Record<string, unknown>, path: string): string | null {
  const origin = origins[path] as { name?: { file?: string } } | undefined;
  const file = origin?.name?.file;
  return typeof file === "string" ? file : null;
}

export function SettingsView({ client }: { client: OpenCliClient }) {
  const [result, setResult] = useState<Record<string, unknown> | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(false);

  useEffect(() => {
    let cancelled = false;
    client
      .readConfig()
      .then((value) => {
        if (!cancelled) setResult(value);
      })
      .catch((err: unknown) => {
        if (!cancelled) setError(err instanceof Error ? err.message : String(err));
      });
    return () => {
      cancelled = true;
    };
  }, [client]);

  const config = (result?.config ?? {}) as Record<string, unknown>;
  const origins = (result?.origins ?? {}) as Record<string, unknown>;
  const entries = flatten(config);
  // A null here means "not set in any file", not "set to nothing" — the
  // built-in default applies. Showing hundreds of them buries the few that
  // were actually configured.
  const set = entries.filter(([, value]) => value !== null && value !== undefined);

  return (
    <section className="panel">
      <h2>Settings</h2>
      <p className="hint">
        What your configuration files set, and which file set it. Anything not listed uses the
        built-in default. Edit <code>~/.opencli/config.toml</code> to change it.
      </p>
      {error ? <p className="error">{error}</p> : null}
      {!result && !error ? <p className="muted">Loading…</p> : null}

      {result ? (
        <>
          <ul className="rows settings">
            {set.length === 0 ? (
              <li className="muted">Nothing configured; all defaults are in use.</li>
            ) : null}
            {set.map(([path, value]) => {
              const file = originFile(origins, path);
              return (
                <li key={path}>
                  <strong>{path}</strong>
                  <span className="value">{JSON.stringify(value)}</span>
                  {file ? <span className="source">{file}</span> : null}
                </li>
              );
            })}
          </ul>

          <button className="secondary" onClick={() => setShowAll(!showAll)}>
            {showAll ? "Hide raw config" : `Show raw config (${entries.length} keys)`}
          </button>
          {showAll ? <pre className="config">{JSON.stringify(config, null, 2)}</pre> : null}
        </>
      ) : null}
    </section>
  );
}

/** Format an interval the way a user would type it. */
function describeInterval(seconds: number): string {
  if (seconds % 86400 === 0) return `every ${seconds / 86400}d`;
  if (seconds % 3600 === 0) return `every ${seconds / 3600}h`;
  if (seconds % 60 === 0) return `every ${seconds / 60}m`;
  return `every ${seconds}s`;
}

function describeWhen(unix: number | null): string {
  if (!unix) return "not yet";
  const delta = unix - Date.now() / 1000;
  const mins = Math.round(Math.abs(delta) / 60);
  if (delta > 0) return mins < 1 ? "due now" : `in ${mins}m`;
  return mins < 1 ? "just now" : `${mins}m ago`;
}

export function ScheduledView({ client, cwd }: { client: OpenCliClient; cwd: string }) {
  const [tasks, setTasks] = useState<ScheduledTask[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [prompt, setPrompt] = useState("");
  const [every, setEvery] = useState("1h");

  const reload = useCallback(async () => {
    try {
      setTasks(await client.listTasks());
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const add = useCallback(async () => {
    const seconds = parseInterval(every);
    if (!seconds) {
      setError("interval must look like 30s, 15m, 2h, or 1d");
      return;
    }
    try {
      await client.createTask({
        name: name.trim() || prompt.trim().slice(0, 40),
        prompt: prompt.trim(),
        intervalSeconds: seconds,
        cwd,
      });
      setName("");
      setPrompt("");
      await reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client, cwd, every, name, prompt, reload]);

  return (
    <section className="panel">
      <h2>Scheduled tasks</h2>
      <p className="hint">
        Prompts that run on a repeat. They run only while OpenCLI is open — this is a local
        agent, not a server.
      </p>
      {error ? <p className="error">{error}</p> : null}

      <div className="task-form">
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Name (optional)"
        />
        <input
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          placeholder="What should it do?"
        />
        <input
          className="interval"
          value={every}
          onChange={(e) => setEvery(e.target.value)}
          placeholder="1h"
        />
        <button onClick={() => void add()} disabled={!prompt.trim()}>
          Add
        </button>
      </div>

      <ul className="rows">
        {tasks.length === 0 ? <li className="muted">No tasks yet.</li> : null}
        {tasks.map((task) => (
          <li key={task.id}>
            <strong>{task.name}</strong>
            <span>{task.prompt}</span>
            <span>
              {describeInterval(task.intervalSeconds)} · next {describeWhen(task.nextRun)} ·{" "}
              {task.enabled ? "active" : "paused"}
            </span>
            <div className="actions">
              <button
                className="secondary"
                onClick={() => {
                  void client.setTaskEnabled(task.id, !task.enabled).then(reload);
                }}
              >
                {task.enabled ? "Pause" : "Resume"}
              </button>
              <button
                className="secondary"
                onClick={() => {
                  void client.deleteTask(task.id).then(reload);
                }}
              >
                Delete
              </button>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Parse `30s` / `15m` / `2h` / `1d`; a bare number is minutes, matching `opencli loop`. */
export function parseInterval(raw: string): number | null {
  const text = raw.trim().toLowerCase();
  if (!text) return null;
  const match = /^(\d+)([smhd]?)$/.exec(text);
  if (!match) return null;
  const value = Number(match[1]);
  if (!Number.isFinite(value) || value <= 0) return null;
  const unit = match[2] || "m";
  const scale = { s: 1, m: 60, h: 3600, d: 86400 }[unit as "s" | "m" | "h" | "d"];
  return value * scale;
}

/**
 * Projects: a saved directory plus standing instructions.
 *
 * Opening one starts a thread in that directory with those instructions
 * already in context, which is the whole point — the alternative is retyping
 * the same preamble at the start of every conversation.
 */
type ProjectSort = "updated" | "created" | "name";

const SORTS: { value: ProjectSort; label: string }[] = [
  { value: "updated", label: "Last updated" },
  { value: "created", label: "Date created" },
  { value: "name", label: "Name" },
];

/** The last part of a path, which is what identifies a folder at a glance. */
function folderName(cwd: string): string {
  return cwd.replace(/\/+$/, "").split("/").pop() || cwd;
}

/**
 * Projects: a card each, newest or pinned first.
 *
 * The form is behind a button rather than always open: this screen is read far
 * more often than it is written to, and a permanent form pushes the list — the
 * thing being looked for — below the fold.
 */
export function ProjectsView({
  client,
  onOpen,
  onBrowse,
}: {
  client: OpenCliClient;
  onOpen: (project: Project) => void;
  /** Opens the platform folder chooser; absent in the browser build. */
  onBrowse?: (start: string) => Promise<string | null>;
}) {
  const [projects, setProjects] = useState<Project[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<Project | null>(null);
  const [composing, setComposing] = useState(false);
  const [sort, setSort] = useState<ProjectSort>("updated");
  const [query, setQuery] = useState("");
  const [searching, setSearching] = useState(false);
  const [draft, setDraft] = useState({ name: "", cwd: "", description: "", instructions: "" });

  const reload = useCallback(async () => {
    try {
      setProjects(await client.listProjects());
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const close = useCallback(() => {
    setComposing(false);
    setEditing(null);
    setDraft({ name: "", cwd: "", description: "", instructions: "" });
  }, []);

  const save = useCallback(async () => {
    try {
      if (editing) {
        await client.updateProject(editing.id, draft);
      } else {
        await client.createProject(draft);
      }
      close();
      await reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client, close, draft, editing, reload]);

  const edit = useCallback((project: Project) => {
    setEditing(project);
    setComposing(true);
    setDraft({
      name: project.name,
      cwd: project.cwd,
      description: project.description,
      instructions: project.instructions,
    });
  }, []);

  const needle = query.trim().toLowerCase();
  const shown = projects
    .filter(
      (project) =>
        !needle ||
        project.name.toLowerCase().includes(needle) ||
        project.description.toLowerCase().includes(needle),
    )
    // Pinned first whatever the sort: pinning is a statement about importance,
    // and a sort that ignored it would make the pin pointless.
    .sort((a, b) => {
      if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
      if (sort === "name") return a.name.localeCompare(b.name);
      if (sort === "created") return b.createdAt - a.createdAt;
      return b.updatedAt - a.updatedAt;
    });

  const canSave = draft.name.trim() !== "" && draft.cwd.trim() !== "";

  return (
    <section className="panel">
      <div className="panel-head">
        <h2 className="display">Projects</h2>
        <span className="grow" />
        {searching ? (
          <input
            className="panel-search"
            value={query}
            autoFocus
            placeholder="Search projects"
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Escape") {
                setSearching(false);
                setQuery("");
              }
            }}
          />
        ) : (
          <button
            className="icon-button"
            aria-label="Search projects"
            onClick={() => setSearching(true)}
          >
            <SearchIcon size={15} />
          </button>
        )}
        <label className="sort">
          Sort by
          <select value={sort} onChange={(e) => setSort(e.target.value as ProjectSort)}>
            {SORTS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <button className="filled" onClick={() => setComposing(true)}>
          New project
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}

      <Dialog
        open={composing}
        title={editing ? "Edit project" : "Create a project"}
        onClose={close}
        footer={
          <>
            <button className="secondary" onClick={close}>
              Cancel
            </button>
            <button className="filled" onClick={() => void save()} disabled={!canSave}>
              {editing ? "Save changes" : "Create project"}
            </button>
          </>
        }
      >
        <label className="field">
          What are you working on?
          <input
            value={draft.name}
            autoFocus
            onChange={(e) => setDraft({ ...draft, name: e.target.value })}
            placeholder="Name your project"
          />
        </label>

        <label className="field">
          What are you trying to achieve?
          <textarea
            value={draft.description}
            onChange={(e) => setDraft({ ...draft, description: e.target.value })}
            placeholder="Describe your project, goals, subject…"
            rows={4}
          />
        </label>

        <label className="field">
          Which folder?
          <span className="path-input">
            <input
              value={draft.cwd}
              onChange={(e) => setDraft({ ...draft, cwd: e.target.value })}
              placeholder="/path/to/project"
            />
            {onBrowse ? (
              <button
                type="button"
                className="ghost"
                onClick={() => {
                  void onBrowse(draft.cwd).then(
                    (picked) => picked && setDraft((current) => ({ ...current, cwd: picked })),
                  );
                }}
              >
                <FolderPlusIcon size={14} />
                Use a folder
              </button>
            ) : null}
          </span>
        </label>

        <details className="more-field">
          <summary>Standing instructions (optional)</summary>
          <p className="hint">
            Given to the agent in every chat here — how to build it, what not to touch. Separate
            from the description above, which only you read.
          </p>
          <textarea
            value={draft.instructions}
            onChange={(e) => setDraft({ ...draft, instructions: e.target.value })}
            rows={3}
          />
        </details>
      </Dialog>

      {shown.length === 0 ? (
        <p className="muted empty-note">
          {query ? "Nothing matches." : "No projects yet. Create one to group chats by directory."}
        </p>
      ) : null}

      <ul className="cards projects">

        {shown.map((project) => (
          <li key={project.id}>
            <div className="card-title">
              <button className="open" onClick={() => onOpen(project)} title={project.cwd}>
                {project.name}
              </button>
              <button
                className={`pin${project.pinned ? " on" : ""}`}
                aria-label={project.pinned ? "Unpin" : "Pin"}
                title={project.pinned ? "Unpin" : "Pin to the top"}
                onClick={() => {
                  void client
                    .updateProject(project.id, { pinned: !project.pinned })
                    .then(reload);
                }}
              >
                <PinIcon size={14} />
              </button>
            </div>
            {project.description ? <p className="card-body">{project.description}</p> : null}

            <div className="card-foot">
              <span>{ago(project.updatedAt)}</span>
              <span className="grow" />
              <span className="chip-plain" title={project.cwd}>
                <FolderIcon size={13} />
                {folderName(project.cwd)}
              </span>
              <span className="chip-plain">
                {project.threadIds.length} chat{project.threadIds.length === 1 ? "" : "s"}
              </span>
            </div>

            <div className="card-hover">
              <button className="secondary" onClick={() => edit(project)}>
                Edit
              </button>
              <button
                className="secondary"
                onClick={() => {
                  void client.deleteProject(project.id).then(reload);
                }}
              >
                Delete
              </button>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * Render what the agent wrote.
 *
 * Only an `update` carries a unified diff. For `add` and `delete` the server
 * puts the whole file content in the same field, so colouring by `+`/`-`
 * prefix there would mislabel ordinary code lines as insertions.
 */
function ChangeBody({ change }: { change: FileChange }) {
  if (change.kind !== "update") {
    return (
      <pre className={`diff ${change.kind === "delete" ? "removed" : "added"}`}>{change.diff}</pre>
    );
  }
  return (
    <pre className="diff">
      {change.diff.split("\n").map((line, index) => {
        const cls = line.startsWith("+")
          ? "added"
          : line.startsWith("-")
            ? "removed"
            : line.startsWith("@@")
              ? "hunk"
              : "";
        return (
          <span key={index} className={cls}>
            {line}
            {"\n"}
          </span>
        );
      })}
    </pre>
  );
}

/**
 * Artifacts: every file the agent wrote this session.
 *
 * The transcript says a file was edited; it does not let you check what was
 * written without leaving the app. Collected per session rather than stored,
 * because the files themselves are already on disk — this is a review surface,
 * not a second copy.
 */
export function ArtifactsView({ changes }: { changes: FileChange[] }) {
  const [openPath, setOpenPath] = useState<string | null>(null);

  // Latest write per path wins: a file edited three times is one artifact.
  const latest = new Map<string, FileChange>();
  for (const change of changes) latest.set(change.path, change);
  const rows = [...latest.values()];

  return (
    <section className="panel">
      <h2>Artifacts</h2>
      <p className="hint">
        Files the agent wrote in this session. The changes are already on disk — this is here so
        you can check them without leaving.
      </p>
      <ul className="rows">
        {rows.length === 0 ? <li className="muted">Nothing written yet.</li> : null}
        {rows.map((change) => (
          <li key={change.path}>
            <strong>{change.path}</strong>
            <span>{change.kind}</span>
            <div className="actions">
              <button
                className="secondary"
                onClick={() => setOpenPath(openPath === change.path ? null : change.path)}
              >
                {openPath === change.path ? "Hide" : change.kind === "update" ? "Show diff" : "Show file"}
              </button>
            </div>
            {openPath === change.path ? <ChangeBody change={change} /> : null}
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * Memory: facts that apply to every conversation, or to one project.
 *
 * Written by the user, not the agent. An agent that decides for itself what to
 * remember will eventually persist something wrong, and a wrong permanent fact
 * is worse than none: invisible, applied to every future conversation, and
 * never agreed to.
 */
export function MemoryView({
  client,
  project,
}: {
  client: OpenCliClient;
  project: Project | null;
}) {
  const [memories, setMemories] = useState<Memory[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [text, setText] = useState("");
  const [scoped, setScoped] = useState(false);

  const reload = useCallback(async () => {
    try {
      setMemories((await client.listMemories()).memories);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const add = useCallback(async () => {
    try {
      await client.createMemory(text.trim(), scoped && project ? project.id : null);
      setText("");
      await reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client, project, reload, scoped, text]);

  return (
    <section className="panel">
      <h2>Memory</h2>
      <p className="hint">
        Facts the agent should always know. They are added to the context of every new chat, so
        keep the list short — each one costs tokens in every conversation.
      </p>
      {error ? <p className="error">{error}</p> : null}

      <div className="task-form">
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="e.g. Deploy with `just ship`, never with npm"
        />
        {project ? (
          <label className="scope">
            <input
              type="checkbox"
              checked={scoped}
              onChange={(e) => setScoped(e.target.checked)}
            />
            Only in {project.name}
          </label>
        ) : null}
        <button onClick={() => void add()} disabled={!text.trim()}>
          Remember
        </button>
      </div>

      <ul className="rows">
        {memories.length === 0 ? <li className="muted">Nothing remembered yet.</li> : null}
        {memories.map((memory) => (
          <li key={memory.id}>
            <strong>{memory.text}</strong>
            <span>{memory.projectId ? "one project only" : "every conversation"}</span>
            <div className="actions">
              <button
                className="secondary"
                onClick={() => {
                  void client.deleteMemory(memory.id).then(reload);
                }}
              >
                Forget
              </button>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * The files a pending approval would write.
 *
 * Approving a write without seeing it is the one thing an approval dialog must
 * not ask for, so the diff is shown inline rather than behind a disclosure.
 */
export function ApprovalChanges({ changes }: { changes: FileChange[] }) {
  if (changes.length === 0) {
    // The contents ride on an earlier notification; if that was missed, say so
    // rather than implying the write is harmless.
    return <p className="error">The contents of this change could not be read.</p>;
  }
  return (
    <div className="approval-changes">
      {changes.map((change) => (
        <div key={change.path}>
          <strong>
            {change.kind} {change.path}
          </strong>
          <ChangeBody change={change} />
        </div>
      ))}
    </div>
  );
}

const PERSONALITIES: { value: Personality; label: string; hint: string }[] = [
  { value: "pragmatic", label: "Pragmatic", hint: "Terse. Answers, not commentary." },
  { value: "friendly", label: "Friendly", hint: "Warmer, more explanatory." },
];

const EFFORTS: { value: ReasoningEffort; label: string }[] = [
  { value: "minimal", label: "Minimal" },
  { value: "low", label: "Low" },
  { value: "medium", label: "Medium" },
  { value: "high", label: "High" },
  { value: "xhigh", label: "Highest" },
];

const POLICIES: { value: ApprovalPolicy; label: string; hint: string }[] = [
  {
    value: "untrusted",
    label: "Ask before anything unfamiliar",
    hint: "Every command that is not known-safe is shown to you first.",
  },
  {
    value: "on-failure",
    label: "Ask only after something fails",
    hint: "Commands run unattended; you are asked when one needs to retry with more access.",
  },
  {
    value: "never",
    label: "Never ask",
    hint: "The agent runs commands on this machine without stopping. Only for a directory you would let a script loose in.",
  },
];

/**
 * Customize: how the agent writes, how hard it thinks, and when it stops to
 * ask.
 *
 * `on-request` is deliberately not offered. It leaves the decision to the
 * model, which in practice almost never asks — so it reads as "never" to
 * anyone who picks it expecting to be consulted, which is the wrong way for a
 * security setting to be wrong.
 */
export function CustomizeView({
  preferences,
  onChange,
  efforts,
}: {
  preferences: Preferences;
  onChange: (next: Preferences) => void;
  /** Efforts the chosen model accepts; empty when it takes none. */
  efforts: string[];
}) {
  const available = EFFORTS.filter((effort) => efforts.includes(effort.value));

  return (
    <section className="panel">
      <h2>Customize</h2>
      <p className="hint">
        Applies to chats you start from now on, except the effort, which applies to your next
        message.
      </p>

      <h3>Tone</h3>
      <div className="choices">
        {PERSONALITIES.map((option) => (
          <label key={option.value} className="choice">
            <input
              type="radio"
              name="personality"
              checked={preferences.personality === option.value}
              onChange={() => onChange({ ...preferences, personality: option.value })}
            />
            <span>
              <strong>{option.label}</strong>
              <span className="hint">{option.hint}</span>
            </span>
          </label>
        ))}
      </div>

      <h3>Thinking effort</h3>
      {available.length === 0 ? (
        <p className="muted">The selected model does not take an effort setting.</p>
      ) : (
        <div className="choices">
          {available.map((option) => (
            <label key={option.value} className="choice">
              <input
                type="radio"
                name="effort"
                checked={preferences.effort === option.value}
                onChange={() => onChange({ ...preferences, effort: option.value })}
              />
              <span>
                <strong>{option.label}</strong>
              </span>
            </label>
          ))}
        </div>
      )}

      <h3>When to ask permission</h3>
      <div className="choices">
        {POLICIES.map((option) => (
          <label key={option.value} className="choice">
            <input
              type="radio"
              name="policy"
              checked={preferences.approvalPolicy === option.value}
              onChange={() => onChange({ ...preferences, approvalPolicy: option.value })}
            />
            <span>
              <strong>{option.label}</strong>
              <span className="hint">{option.hint}</span>
            </span>
          </label>
        ))}
      </div>
      {preferences.approvalPolicy === "never" ? (
        <p className="error">
          The agent will run commands on this machine without asking.
        </p>
      ) : null}
    </section>
  );
}

/** How long ago, in the words a person would use. */
export function ago(unix: number | null): string {
  if (!unix) return "";
  const days = Math.floor((Date.now() / 1000 - unix) / 86400);
  if (days <= 0) {
    const mins = Math.floor((Date.now() / 1000 - unix) / 60);
    if (mins < 1) return "just now";
    if (mins < 60) return `${mins}m ago`;
    return `${Math.floor(mins / 60)}h ago`;
  }
  if (days === 1) return "yesterday";
  return `${days} days ago`;
}

const STATUS_LABEL: Record<RunStatus, string> = {
  queued: "Queued",
  running: "Running",
  done: "Done",
  failed: "Failed",
  cancelled: "Cancelled",
};

/** One run, expandable to show what it printed. */
function RunRow({
  run,
  onCancel,
  onDelete,
}: {
  run: Run;
  onCancel: (id: string) => void;
  onDelete: (id: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const finished = run.status === "done" || run.status === "failed" || run.status === "cancelled";

  return (
    <li className={`run ${run.status}`}>
      <div className="run-head">
        <i className={`run-dot ${run.status}`} />
        <span className="run-what">
          <strong>{run.title}</strong>
          <em>
            {STATUS_LABEL[run.status]} · {ago(run.finishedAt ?? run.startedAt)} · {run.source}
          </em>
        </span>
        <span className="actions">
          {run.output ? (
            <button className="secondary" onClick={() => setOpen(!open)}>
              {open ? "Hide" : "Output"}
            </button>
          ) : null}
          {finished ? (
            <button className="secondary" onClick={() => onDelete(run.id)}>
              Remove
            </button>
          ) : (
            <button className="secondary" onClick={() => onCancel(run.id)}>
              Cancel
            </button>
          )}
        </span>
      </div>
      {open ? <pre className="run-output">{run.output}</pre> : null}
    </li>
  );
}

/**
 * Dispatch: work started here and left to finish on its own.
 *
 * Runs are polled rather than pushed. The gateway owns them, not the thread,
 * so there is no per-run notification to subscribe to — and a run takes
 * minutes, so a few seconds of staleness costs nothing.
 */
export function DispatchView({ client, cwd, model }: { client: OpenCliClient; cwd: string; model: string }) {
  const [runs, setRuns] = useState<Run[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [prompt, setPrompt] = useState("");
  const [directory, setDirectory] = useState(cwd);

  const reload = useCallback(async () => {
    try {
      setRuns(await client.listRuns({ limit: 100 }));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
    const timer = setInterval(() => void reload(), 4000);
    return () => clearInterval(timer);
  }, [reload]);

  const dispatch = useCallback(async () => {
    try {
      await client.dispatchRun({
        prompt: prompt.trim(),
        cwd: directory || ".",
        ...(model ? { model } : {}),
      });
      setPrompt("");
      await reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client, directory, model, prompt, reload]);

  const active = runs.filter((run) => run.status === "queued" || run.status === "running");
  const past = runs.filter((run) => run.status !== "queued" && run.status !== "running");

  return (
    <section className="panel">
      <h2>Dispatch</h2>
      <p className="hint">
        Send work off to run on its own. Each run is a separate agent in its own directory, so it
        keeps going after you close the chat that started it. Three run at a time.
      </p>
      {error ? <p className="error">{error}</p> : null}

      <div className="project-form">
        <textarea
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          placeholder="What should it do?"
          rows={3}
        />
        <span className="path-input">
          <input
            value={directory}
            onChange={(e) => setDirectory(e.target.value)}
            placeholder="/path/to/work/in"
          />
        </span>
        <div className="actions">
          <button onClick={() => void dispatch()} disabled={!prompt.trim()}>
            Dispatch
          </button>
        </div>
      </div>

      <h3>Active</h3>
      <ul className="rows">
        {active.length === 0 ? <li className="muted">Nothing running.</li> : null}
        {active.map((run) => (
          <RunRow
            key={run.id}
            run={run}
            onCancel={(id) => void client.cancelRun(id).then(reload)}
            onDelete={(id) => void client.deleteRun(id).then(reload)}
          />
        ))}
      </ul>

      <h3>
        Finished
        {past.length > 0 ? (
          <button className="link clear" onClick={() => void client.clearRuns().then(reload)}>
            Clear
          </button>
        ) : null}
      </h3>
      <ul className="rows">
        {past.length === 0 ? <li className="muted">Nothing has run yet.</li> : null}
        {past.map((run) => (
          <RunRow
            key={run.id}
            run={run}
            onCancel={(id) => void client.cancelRun(id).then(reload)}
            onDelete={(id) => void client.deleteRun(id).then(reload)}
          />
        ))}
      </ul>
    </section>
  );
}

/**
 * Plugins: the skills installed on this machine, and the ones on offer.
 *
 * A skill is a directory the agent reads when a task calls for it, so
 * installing one is a clone and removing one is a delete. There is no hosted
 * marketplace behind this — the catalogue is a short list of repositories that
 * exist, plus a field for any other.
 */
export function PluginsView({ client }: { client: OpenCliClient }) {
  const [installed, setInstalled] = useState<InstalledPlugin[]>([]);
  const [offers, setOffers] = useState<PluginOffer[]>([]);
  const [tab, setTab] = useState<"yours" | "discover">("discover");
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [custom, setCustom] = useState({ name: "", source: "" });

  const reload = useCallback(async () => {
    try {
      const [rows, catalogued] = await Promise.all([client.listPlugins(), client.pluginCatalog()]);
      setInstalled(rows);
      setOffers(catalogued);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const install = useCallback(
    async (name: string, source: string) => {
      setBusy(name);
      setNote(null);
      try {
        const result = await client.installPlugin(name, source);
        setNote(
          result.loadable
            ? `Installed ${result.name}. It is available in new chats.`
            : `Installed ${result.name}, but it has no SKILL.md at its root — it is a collection, not a skill the agent loads on its own.`,
        );
        setError(null);
        await reload();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      } finally {
        setBusy(null);
      }
    },
    [client, reload],
  );

  const needle = query.trim().toLowerCase();
  const matches = <T extends { name: string; description: string }>(row: T) =>
    !needle ||
    row.name.toLowerCase().includes(needle) ||
    row.description.toLowerCase().includes(needle);

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>Plugins</h2>
        <input
          className="panel-search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search skills and plugins"
        />
      </div>

      <div className="tabs">
        <button className={tab === "yours" ? "on" : ""} onClick={() => setTab("yours")}>
          Your plugins
        </button>
        <button className={tab === "discover" ? "on" : ""} onClick={() => setTab("discover")}>
          Discover
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {note ? <p className="hint">{note}</p> : null}

      {tab === "yours" ? (
        <ul className="cards">
          {installed.filter(matches).length === 0 ? (
            <li className="muted">Nothing installed yet.</li>
          ) : null}
          {installed.filter(matches).map((plugin) => (
            <li key={plugin.name}>
              <strong>{plugin.name}</strong>
              <span>{plugin.description || "No description."}</span>
              <div className="actions">
                <button
                  className="secondary"
                  onClick={() => void client.removePlugin(plugin.name).then(reload)}
                >
                  Remove
                </button>
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <>
          <ul className="cards">
            {offers.filter(matches).map((offer) => {
              const already = installed.some((plugin) => plugin.name === offer.id);
              return (
                <li key={offer.id}>
                  <strong>{offer.name}</strong>
                  <span>{offer.description}</span>
                  {offer.note ? <span className="muted">{offer.note}</span> : null}
                  <div className="actions">
                    <button
                      disabled={already || busy === offer.id}
                      onClick={() => void install(offer.id, offer.source)}
                    >
                      {already ? "Installed" : busy === offer.id ? "Installing…" : "Add"}
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>

          <h3>Install from a repository</h3>
          <div className="task-form">
            <input
              value={custom.name}
              onChange={(e) => setCustom({ ...custom, name: e.target.value })}
              placeholder="Name"
            />
            <input
              value={custom.source}
              onChange={(e) => setCustom({ ...custom, source: e.target.value })}
              placeholder="https://github.com/owner/repo"
            />
            <button
              disabled={!custom.name.trim() || !custom.source.trim() || busy !== null}
              onClick={() => {
                void install(custom.name.trim(), custom.source.trim()).then(() =>
                  setCustom({ name: "", source: "" }),
                );
              }}
            >
              Install
            </button>
          </div>
        </>
      )}
    </section>
  );
}
