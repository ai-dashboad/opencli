import { useCallback, useEffect, useState } from "react";
import { FolderIcon, FolderPlusIcon, PinIcon, SearchIcon } from "./icons";
import { Dialog } from "./menus";
import { shouldDismiss, shouldSend } from "./composer";
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
  InstallTarget,
  ModelLocation,
  ModelVariant,
  Project,
  ProjectFile,
  PullProgress,
  Run,
  Diagnosis,
  DiscoveredRuntime,
  Offer,
  ServerEntry,
  SshAlias,
  RunStatus,
  ScheduledTask,
  SkillSummary,
  ThreadSummary,
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
 * Turn a project name into a folder name.
 *
 * Spaces and punctuation become dashes: a folder is typed at a shell and
 * quoted in scripts, and one named `My Project (v2)` is a nuisance in both.
 * The server applies the same rule; this is only to show the path as it is
 * typed.
 */
function slug(name: string): string {
  return name
    .replace(/[^a-zA-Z0-9._]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
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
  const [root, setRoot] = useState("");
  // Once the path is chosen by hand, the name must stop overwriting it.
  const [pathTouched, setPathTouched] = useState(false);

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

  useEffect(() => {
    void client
      .projectsRoot()
      .then((where) => setRoot(where.root))
      .catch(() => setRoot(""));
  }, [client]);

  const close = useCallback(() => {
    setComposing(false);
    setEditing(null);
    setPathTouched(false);
    setDraft({ name: "", cwd: "", description: "", instructions: "" });
  }, []);

  const save = useCallback(async () => {
    try {
      if (editing) {
        await client.updateProject(editing.id, draft);
      } else {
        // The folder is usually new; making it is the point of suggesting a
        // path rather than demanding one that already exists.
        await client.createProject({ ...draft, createDirectory: true });
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
    setPathTouched(true);
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
              if (shouldDismiss({ ...e, isComposing: e.nativeEvent.isComposing })) {
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
            onChange={(e) => {
              const name = e.target.value;
              const folder = slug(name);
              setDraft({
                ...draft,
                name,
                // Follow the name until the path is edited or browsed to.
                cwd: pathTouched || !root ? draft.cwd : folder ? `${root}/${folder}` : "",
              });
            }}
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
              onChange={(e) => {
                setPathTouched(true);
                setDraft({ ...draft, cwd: e.target.value });
              }}
              placeholder="/path/to/project"
            />
            {onBrowse ? (
              <button
                type="button"
                className="ghost"
                onClick={() => {
                  void onBrowse(draft.cwd || root).then((picked) => {
                    if (!picked) return;
                    setPathTouched(true);
                    setDraft((current) => ({ ...current, cwd: picked }));
                  });
                }}
              >
                <FolderPlusIcon size={14} />
                Use a folder
              </button>
            ) : null}
          </span>
          {!editing && draft.cwd && !pathTouched ? (
            <span className="field-note">
              This folder will be created if it does not exist.
            </span>
          ) : null}
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

/** A size a person can read at a glance. */
function readableSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/**
 * One project: its chats, what it holds, and what the agent is told about it.
 *
 * Reached by clicking a project rather than starting a chat in it — opening a
 * chat immediately would make the description, the instructions and the
 * existing conversations unreachable.
 */
export function ProjectDetailView({
  client,
  project,
  threads,
  onNewChat,
  onOpenThread,
  onChanged,
  onBack,
}: {
  client: OpenCliClient;
  project: Project;
  threads: ThreadSummary[];
  onNewChat: () => void;
  onOpenThread: (id: string) => void;
  onChanged: () => void;
  onBack: () => void;
}) {
  const [files, setFiles] = useState<ProjectFile[]>([]);
  const [filesError, setFilesError] = useState<string | null>(null);
  const [instructions, setInstructions] = useState(project.instructions);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    setInstructions(project.instructions);
    setSaved(false);
  }, [project.id, project.instructions]);

  useEffect(() => {
    let cancelled = false;
    client
      .projectFiles(project.id)
      .then((rows) => {
        if (!cancelled) {
          setFiles(rows);
          setFilesError(null);
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) setFilesError(err instanceof Error ? err.message : String(err));
      });
    return () => {
      cancelled = true;
    };
  }, [client, project.id]);

  const own = project.threadIds
    .map((id) => threads.find((thread) => thread.id === id))
    .filter((thread): thread is ThreadSummary => thread !== undefined)
    .reverse();

  return (
    <section className="panel">
      <div className="panel-head">
        <button className="link back" onClick={onBack}>
          ← Projects
        </button>
      </div>

      <div className="panel-head">
        <h2 className="display">{project.name}</h2>
        <span className="grow" />
        <button className="filled" onClick={onNewChat}>
          New chat
        </button>
      </div>
      <p className="hint">
        {project.description || "No description."} · {project.cwd}
      </p>

      <h3>Chats</h3>
      <ul className="rows">
        {own.length === 0 ? (
          <li className="muted">No chats here yet. Start one and it will be grouped here.</li>
        ) : null}
        {own.map((thread) => (
          <li key={thread.id}>
            <strong>{thread.name ?? thread.preview}</strong>
            <span>{ago(thread.updatedAt)}</span>
            <div className="actions">
              <button className="secondary" onClick={() => onOpenThread(thread.id)}>
                Open
              </button>
            </div>
          </li>
        ))}
      </ul>

      <h3>In this folder</h3>
      {filesError ? <p className="error">{filesError}</p> : null}
      <ul className="rows files">
        {!filesError && files.length === 0 ? <li className="muted">Empty.</li> : null}
        {files.map((file) => (
          <li key={file.name}>
            <strong>
              {file.isDir ? <FolderIcon size={13} /> : null}
              {file.name}
            </strong>
            <span>{file.isDir ? "folder" : readableSize(file.size)}</span>
          </li>
        ))}
      </ul>

      <h3>Standing instructions</h3>
      <p className="hint">
        Given to the agent in every chat opened here. Changes apply to the next chat, not the one
        already open.
      </p>
      <div className="project-form">
        <textarea
          value={instructions}
          onChange={(e) => {
            setInstructions(e.target.value);
            setSaved(false);
          }}
          rows={5}
          placeholder="How to build it, what not to touch…"
        />
        <div className="actions">
          <button
            disabled={instructions === project.instructions}
            onClick={() => {
              void client
                .updateProject(project.id, { instructions })
                .then(() => {
                  setSaved(true);
                  onChanged();
                });
            }}
          >
            Save
          </button>
          {saved ? <span className="field-note">Saved.</span> : null}
        </div>
      </div>
    </section>
  );
}

/** A size a person can read, for models measured in gigabytes. */
function modelSize(bytes: number): string {
  if (bytes >= 1e9) return `${(bytes / 1e9).toFixed(1)} GB`;
  if (bytes >= 1e6) return `${Math.round(bytes / 1e6)} MB`;
  return `${bytes} B`;
}

/** Models worth suggesting, with what each is for. */
/**
 * Models: what is installed on a runtime, and what can be added.
 *
 * The runtime may be on this machine or a server elsewhere. Ollama's
 * management API is plain HTTP, so a machine with no shell available can still
 * be told to fetch a model — the whole reason this panel can exist.
 *
 * Three places to find one: a short curated library, Hugging Face (searchable,
 * and installable because the runtime resolves `hf.co/owner/repo` directly),
 * and ModelScope. Whether a model calls tools is stated wherever it is known,
 * and left unstated where only the runtime can say — guessing at the one fact
 * that decides usefulness would be worse than admitting ignorance.
 */
/**
 * Models: what is installed where, and what can be added.
 *
 * One panel rather than two. A machine, a runtime on it, models on that
 * runtime, and a model usable in chat are a chain — each step is meaningless
 * without the one before. Presenting machines and models as sibling entries
 * hid that, and let a server be chosen in two places that did not agree.
 *
 * The empty states carry the order: nothing found points at looking on this
 * machine, an unreachable machine shows what is wrong inline, no models puts
 * the library right there, and an installed model offers itself to chats.
 */
/**
 * Models: what you have, and what you could add.
 *
 * Model-first, not machine-first. A machine holds models, but the thought is
 * "I want a coding model" — not "let me look inside the GPU box". Scoping the
 * page to one machine meant models spread across several could only be seen by
 * switching between them, and made choosing a machine a thing you did *before*
 * knowing what you wanted.
 *
 * So: everything installed, wherever it lives, in one list. And when
 * installing, the machine is chosen then — alongside the quantisation, whose
 * recommendation depends on which machine was picked.
 */
export function ModelsView({
  client,
  pulls,
  onPull,
}: {
  client: OpenCliClient;
  /** Downloads in flight, keyed by tag. */
  pulls: Record<string, PullProgress>;
  onPull: (baseUrl: string, model: string) => void;
}) {
  const [tab, setTab] = useState<"installed" | "browse">("installed");
  const [installed, setInstalled] = useState<ModelLocation[]>([]);
  const [library, setLibrary] = useState<Offer[]>([]);
  const [found, setFound] = useState<Offer[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [needsReload, setNeedsReload] = useState(false);
  const [managing, setManaging] = useState(false);
  const [discovered, setDiscovered] = useState<DiscoveredRuntime[]>([]);

  const [source, setSource] = useState<"ollama" | "huggingface" | "modelscope">("ollama");
  const [query, setQuery] = useState("");
  const [hint, setHint] = useState<string | null>(null);
  const [searching, setSearching] = useState(false);
  const [installing, setInstalling] = useState<Offer | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const [rows, here] = await Promise.all([
        client.allInstalledModels(),
        client.discoverRuntimes().catch(() => []),
      ]);
      setInstalled(rows);
      setDiscovered(here);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    void reload();
    void client.modelCatalog().then(setLibrary).catch(() => setLibrary([]));
  }, [client, reload]);

  // A finished download is registered where it landed, then the list refreshed.
  const finished = Object.values(pulls)
    .filter((pull) => pull.done)
    .map((pull) => `${pull.model}@${pull.baseUrl ?? ""}`)
    .join(",");
  useEffect(() => {
    if (!finished) return;
    void (async () => {
      let registered = 0;
      for (const pair of finished.split(",")) {
        const [model, baseUrl] = pair.split("@");
        if (!baseUrl) continue;
        try {
          const result = await client.registerModel(baseUrl, model);
          if (result.added) registered += 1;
        } catch {
          // Installed either way; failing to register only means it must be
          // chosen by editing config.toml.
        }
      }
      if (registered > 0) setNeedsReload(true);
      // Back to what you now own, which is where a finished install belongs.
      setTab("installed");
      await reload();
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [finished]);

  const runSearch = useCallback(() => {
    if (source === "ollama") {
      void client.modelCatalog({ query }).then(setLibrary);
      return;
    }
    if (!query.trim()) return;
    setSearching(true);
    void client
      .searchModels(query.trim(), source)
      .then((result) => {
        setFound(result.results);
        setHint(result.hint ?? null);
      })
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)))
      .finally(() => setSearching(false));
  }, [client, query, source]);

  const inFlight = Object.values(pulls).filter((pull) => !pull.done && !pull.error);
  const offers = source === "ollama" ? library : found;

  // Which machines hold each model, rather than a yes or no: "already on GPU
  // Box" is what someone deciding needs, and it is also what makes clear that
  // installing it somewhere else is still open to them.
  const whereInstalled = new Map<string, string[]>();
  for (const row of installed) {
    whereInstalled.set(row.model.name, [
      ...(whereInstalled.get(row.model.name) ?? []),
      row.server,
    ]);
  }

  // Typing a tag rather than a name is a real way to arrive; offering it as a
  // result beats a second field beside the search box.
  const typedTag =
    query.trim().includes(":") || query.trim().includes("/") ? query.trim() : null;

  return (
    <section className="panel">
      <div className="panel-head">
        <h2 className="display">Models</h2>
        <span className="grow" />
        <button className="secondary" onClick={() => setManaging(true)}>
          Machines…
        </button>
      </div>

      <div className="tabs">
        <button className={tab === "installed" ? "on" : ""} onClick={() => setTab("installed")}>
          Installed{installed.length > 0 ? ` (${installed.length})` : ""}
        </button>
        <button className={tab === "browse" ? "on" : ""} onClick={() => setTab("browse")}>
          Browse
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {needsReload ? (
        <p className="notice">
          Added to your configuration. Start a new chat to use it — the agent reads its settings
          when a chat opens.
        </p>
      ) : null}

      {inFlight.length > 0 ? (
        <ul className="rows">
          {inFlight.map((pull) => {
            const pct =
              pull.total && pull.completed ? Math.round((100 * pull.completed) / pull.total) : null;
            return (
              <li key={pull.model}>
                <strong>{pull.model}</strong>
                <span>
                  {pull.status}
                  {pct !== null ? ` · ${pct}% of ${modelSize(pull.total ?? 0)}` : ""}
                </span>
                {pct !== null ? (
                  <span className="bar">
                    <i style={{ width: `${pct}%` }} />
                  </span>
                ) : null}
              </li>
            );
          })}
        </ul>
      ) : null}

      {Object.values(pulls).some((pull) => pull.error) ? (
        <ul className="rows">
          {Object.values(pulls)
            .filter((pull) => pull.error)
            .map((pull) => (
              <li key={pull.model}>
                <strong>{pull.model}</strong>
                <span className="error">{pull.error}</span>
              </li>
            ))}
        </ul>
      ) : null}

      {tab === "installed" ? (
        <>
          {loading ? <p className="muted">Looking on every machine…</p> : null}
          {!loading && installed.length === 0 ? (
            <p className="muted">
              Nothing installed anywhere yet. Open Browse to add one.
            </p>
          ) : null}
          <ul className="rows">
            {installed.map((row) => (
              <li key={`${row.baseUrl}:${row.model.name}`}>
                <strong>{row.model.name}</strong>
                <span>
                  <span className="chip-plain">{row.server}</span>
                  {" · "}
                  {modelSize(row.model.size)}
                  {row.model.parameterSize ? ` · ${row.model.parameterSize}` : ""}
                  {row.model.quantization ? ` · ${row.model.quantization}` : ""}
                  {row.capabilities?.contextLength
                    ? ` · ${Math.round(row.capabilities.contextLength / 1024)}K context`
                    : ""}
                </span>
                {row.capabilities ? (
                  <span className={row.capabilities.supportsTools ? "" : "warn"}>
                    {row.capabilities.supportsTools
                      ? "Calls tools"
                      : "Does not call tools — of little use for agent work here"}
                  </span>
                ) : null}
                <div className="actions">
                  <button
                    className="secondary"
                    title="Add it to the model picker"
                    onClick={() => {
                      void client
                        .registerModel(row.baseUrl, row.model.name)
                        .then((result) => {
                          setError(null);
                          if (result.added) setNeedsReload(true);
                        })
                        .catch((err: unknown) =>
                          setError(err instanceof Error ? err.message : String(err)),
                        );
                    }}
                  >
                    Use in chats
                  </button>
                  <button
                    className="secondary"
                    onClick={() => {
                      void client
                        .deleteModel(row.baseUrl, row.model.name)
                        .then(reload)
                        .catch((err: unknown) =>
                          setError(err instanceof Error ? err.message : String(err)),
                        );
                    }}
                  >
                    Remove
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </>
      ) : (
        <>
          <div className="tabs">
            {(["ollama", "huggingface", "modelscope"] as const).map((option) => (
              <button
                key={option}
                className={source === option ? "on" : ""}
                onClick={() => {
                  setSource(option);
                  setFound([]);
                  setHint(null);
                }}
              >
                {option === "ollama"
                  ? "Recommended"
                  : option === "huggingface"
                    ? "Hugging Face"
                    : "ModelScope"}
              </button>
            ))}
          </div>

          <div className="task-form">
            <input
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                if (source === "ollama") {
                  void client.modelCatalog({ query: e.target.value }).then(setLibrary);
                }
              }}
              onKeyDown={(e) => {
                if (shouldSend({ ...e, isComposing: e.nativeEvent.isComposing })) runSearch();
              }}
              placeholder={
                source === "ollama"
                  ? "Filter, or paste a tag like mistral:7b"
                  : "Search by name, then press Enter"
              }
            />
            {source !== "ollama" ? (
              <button disabled={!query.trim() || searching} onClick={runSearch}>
                {searching ? "Searching…" : "Search"}
              </button>
            ) : null}
          </div>

          {hint ? <p className="hint">{hint}</p> : null}

          {typedTag && !offers.some((offer) => offer.tag === typedTag) ? (
            <ul className="rows">
              <li>
                <strong>{typedTag}</strong>
                <span>Install this exactly as typed.</span>
                <div className="actions">
                  <button
                    onClick={() =>
                      setInstalling({ source: "ollama", tag: typedTag, name: typedTag, tools: null })
                    }
                  >
                    Install
                  </button>
                </div>
              </li>
            </ul>
          ) : null}

          {source === "ollama" ? (
            <PurposeGroups
              offers={offers}
              whereInstalled={whereInstalled}
              onInstall={setInstalling}
            />
          ) : (
            <ul className="rows">
              {offers.length === 0 ? (
                <li className="muted">Nothing found yet — search above.</li>
              ) : null}
              {offers.map((offer) => (
                <OfferRow
                  key={offer.tag}
                  offer={offer}
                  where={whereInstalled.get(offer.tag) ?? []}
                  onInstall={() => setInstalling(offer)}
                />
              ))}
            </ul>
          )}
        </>
      )}

      <InstallDialog
        client={client}
        offer={installing}
        onClose={() => setInstalling(null)}
        onInstall={(baseUrl, tag) => {
          onPull(baseUrl, tag);
          setInstalling(null);
        }}
      />

      <MachinesDialog
        client={client}
        open={managing}
        discovered={discovered}
        onClose={() => {
          setManaging(false);
          void reload();
        }}
      />
    </section>
  );
}

/**
 * One model on offer.
 *
 * `where` names the machines that already have it. It is shown, but it does
 * not disable installing: having a model on one machine is a reason to want it
 * on another, not a reason to be refused. Whether *this* machine already has
 * it is a question the install dialog answers, because that is where the
 * machine is chosen.
 */
function OfferRow({
  offer,
  where,
  onInstall,
}: {
  offer: Offer;
  where: string[];
  onInstall: () => void;
}) {
  return (
    <li>
      <strong>{offer.name}</strong>
      {offer.note ? <span>{offer.note}</span> : null}
      <span>
        {offer.sizeGb ? `${offer.sizeGb.toFixed(1)} GB` : ""}
        {offer.needsGb ? ` · needs about ${offer.needsGb.toFixed(0)} GB of memory` : ""}
        {offer.context ? ` · ${Math.round(offer.context / 1024)}K context` : ""}
        {offer.downloads ? `${offer.downloads.toLocaleString()} downloads` : ""}
      </span>
      {offer.tools === false ? (
        <span className="warn">Does not call tools — cannot drive the agent&apos;s own work</span>
      ) : null}
      {offer.tools === null && offer.source === "huggingface" ? (
        <span>Whether it calls tools is only known once installed.</span>
      ) : null}
      {where.length > 0 ? (
        <span className="chip-plain">Already on {where.join(", ")}</span>
      ) : null}
      <div className="actions">
        <button onClick={onInstall}>
          {where.length > 0 ? "Install elsewhere" : "Install"}
        </button>
      </div>
    </li>
  );
}

/** The recommended catalogue, grouped by what a model is for. */
function PurposeGroups({
  offers,
  whereInstalled,
  onInstall,
}: {
  offers: Offer[];
  whereInstalled: Map<string, string[]>;
  onInstall: (offer: Offer) => void;
}) {
  const groups: { id: string; label: string }[] = [
    { id: "coding", label: "Coding" },
    { id: "general", label: "General purpose" },
    { id: "small", label: "Small and fast" },
  ];

  return (
    <>
      {groups.map((group) => {
        const rows = offers.filter((offer) => offer.purpose === group.id);
        if (rows.length === 0) return null;
        return (
          <div key={group.id}>
            <h3>{group.label}</h3>
            <ul className="rows">
              {rows.map((offer) => (
                <OfferRow
                  key={offer.tag}
                  offer={offer}
                  where={whereInstalled.get(offer.tag) ?? []}
                  onInstall={() => onInstall(offer)}
                />
              ))}
            </ul>
          </div>
        );
      })}
    </>
  );
}

/**
 * Where to install, and which version.
 *
 * The two decisions belong together: which quantisation is best depends on the
 * memory of the machine chosen, so choosing a machine changes what is
 * recommended.
 */
function InstallDialog({
  client,
  offer,
  onClose,
  onInstall,
}: {
  client: OpenCliClient;
  offer: Offer | null;
  onClose: () => void;
  onInstall: (baseUrl: string, tag: string) => void;
}) {
  const [targets, setTargets] = useState<InstallTarget[]>([]);
  const [chosen, setChosen] = useState<string>("");
  const [variants, setVariants] = useState<ModelVariant[]>([]);
  const [variant, setVariant] = useState<string>("");
  const [showVariants, setShowVariants] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const needsVariant = offer?.source === "huggingface" && offer.needsQuant;

  useEffect(() => {
    if (!offer) return;
    setLoading(true);
    setError(null);
    setShowVariants(false);
    void client
      .installTargets()
      .then((rows) => {
        setTargets(rows);
        // Prefer somewhere it can actually go, and somewhere it is not already.
        const usable = rows.find(
          (row) => row.reachable && !row.installed.includes(offer.tag),
        );
        setChosen(usable?.baseUrl ?? rows.find((row) => row.reachable)?.baseUrl ?? "");
      })
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)))
      .finally(() => setLoading(false));
  }, [client, offer]);

  // The recommendation follows the machine, so it is fetched again when the
  // machine changes rather than chosen once.
  useEffect(() => {
    if (!offer || !needsVariant || !chosen) return;
    const memory = targets.find((row) => row.baseUrl === chosen)?.memoryGb ?? undefined;
    void client
      .modelVariants(offer.tag, memory ?? undefined)
      .then((result) => {
        setVariants(result.variants);
        setVariant(result.recommended ?? result.variants[0]?.tag ?? "");
      })
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [client, offer, needsVariant, chosen, targets]);

  if (!offer) return null;

  const target = targets.find((row) => row.baseUrl === chosen);
  const tag = needsVariant ? variant : offer.tag;
  const already = target?.installed.includes(tag) ?? false;
  const chosenVariant = variants.find((row) => row.tag === variant);
  const fits =
    target?.memoryGb == null
      ? null
      : needsVariant
        ? (chosenVariant?.fits ?? null)
        : offer.needsGb
          ? offer.needsGb <= target.memoryGb
          : null;

  return (
    <Dialog
      open
      title={`Install ${offer.name}`}
      onClose={onClose}
      footer={
        <>
          <button className="secondary" onClick={onClose}>
            Cancel
          </button>
          <button
            className="filled"
            disabled={!chosen || !tag || already || loading}
            onClick={() => onInstall(chosen, tag)}
          >
            {already ? "Already there" : "Install"}
          </button>
        </>
      }
    >
      {error ? <p className="error">{error}</p> : null}
      {loading ? <p className="muted">Looking at your machines…</p> : null}

      <label className="field">
        Which machine?
        {targets.length === 0 && !loading ? (
          <span className="field-note">
            No machine found. Open Machines… to add one, or install Ollama on this computer.
          </span>
        ) : null}
        <select value={chosen} onChange={(e) => setChosen(e.target.value)}>
          {targets.map((row) => (
            <option key={row.baseUrl} value={row.baseUrl} disabled={!row.reachable}>
              {row.label}
              {row.reachable ? "" : " — not answering"}
              {row.memoryGb ? ` · ${row.memoryGb} GB` : ""}
            </option>
          ))}
        </select>
        {target && fits === false ? (
          <span className="field-note warn">
            This is larger than the memory on that machine. It will download, and may fail to
            load.
          </span>
        ) : null}
        {target && target.memoryGb == null ? (
          <span className="field-note">
            How much memory that machine has cannot be read from here, so whether it fits is not
            known. Adding an SSH alias in Machines… would let it be checked.
          </span>
        ) : null}
        {already ? (
          <span className="field-note">It is already installed there.</span>
        ) : null}
      </label>

      {needsVariant ? (
        <div className="field">
          Which version?
          {chosenVariant ? (
            <div className="variant-chosen">
              <strong>{chosenVariant.quant}</strong>
              <span>
                {chosenVariant.sizeGb.toFixed(1)} GB · {chosenVariant.note}
              </span>
              <button className="link" onClick={() => setShowVariants(!showVariants)}>
                {showVariants ? "Keep this one" : "Choose a different one"}
              </button>
            </div>
          ) : (
            <span className="field-note">Reading the available versions…</span>
          )}

          {showVariants ? (
            <ul className="rows">
              {variants.map((row) => (
                <li key={row.tag}>
                  <label className="choice">
                    <input
                      type="radio"
                      name="variant"
                      checked={variant === row.tag}
                      onChange={() => {
                        setVariant(row.tag);
                        setShowVariants(false);
                      }}
                    />
                    <span>
                      <strong>
                        {row.quant} · {row.sizeGb.toFixed(1)} GB
                      </strong>
                      <span className="hint">
                        {row.note}
                        {row.fits === false ? " — larger than this machine's memory" : ""}
                      </span>
                    </span>
                  </label>
                </li>
              ))}
            </ul>
          ) : null}
        </div>
      ) : null}
    </Dialog>
  );
}

/**
 * The machines that serve models: saved ones, and whatever is on this machine.
 *
 * A dialog rather than a page. Adding a machine happens once and then rarely;
 * a permanent entry beside Models would suggest they are separate things when
 * one contains the other.
 */
function MachinesDialog({
  client,
  open,
  discovered,
  onClose,
}: {
  client: OpenCliClient;
  open: boolean;
  discovered: DiscoveredRuntime[];
  onClose: () => void;
}) {
  const [servers, setServers] = useState<ServerEntry[]>([]);
  const [aliases, setAliases] = useState<SshAlias[]>([]);
  const [reports, setReports] = useState<Record<string, Diagnosis>>({});
  const [checking, setChecking] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState({ name: "", baseUrl: "", sshAlias: "" });

  const reload = useCallback(async () => {
    try {
      const [rows, hosts] = await Promise.all([client.listServers(), client.sshAliases()]);
      setServers(rows);
      setAliases(hosts);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    if (open) void reload();
  }, [open, reload]);

  const unsaved = discovered.filter(
    (runtime) => !servers.some((server) => server.baseUrl === runtime.baseUrl),
  );

  return (
    <Dialog open={open} title="Machines" onClose={onClose}>
      {error ? <p className="error">{error}</p> : null}

      {unsaved.length > 0 ? (
        <>
          <h3>Found on this machine</h3>
          <ul className="rows">
            {unsaved.map((runtime) => (
              <li key={runtime.baseUrl}>
                <strong>{runtime.name}</strong>
                <span>
                  {runtime.baseUrl}
                  {runtime.version ? ` · ${runtime.version}` : ""}
                  {runtime.manageable ? "" : " · serves models but cannot install them"}
                </span>
                <div className="actions">
                  <button
                    onClick={() => {
                      void client
                        .addServer({ name: `${runtime.name} (this machine)`, baseUrl: runtime.baseUrl })
                        .then(reload)
                        .catch((err: unknown) =>
                          setError(err instanceof Error ? err.message : String(err)),
                        );
                    }}
                  >
                    Save it
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </>
      ) : null}

      <h3>Saved</h3>
      <ul className="rows">
        {servers.length === 0 ? <li className="muted">None saved.</li> : null}
        {servers.map((server) => {
          const report = reports[server.id];
          return (
            <li key={server.id}>
              <strong>{server.name}</strong>
              <span>{server.baseUrl}</span>
              <span>
                {server.sshAlias
                  ? `SSH: ${server.sshAlias} — can be inspected and repaired`
                  : "No SSH — models only"}
              </span>

              {report ? (
                <div className="report">
                  {report.shell ? (
                    <dl>
                      <dt>Runtime</dt>
                      <dd>
                        {report.http.reachable
                          ? `answering, ${report.http.version}`
                          : "not answering"}
                      </dd>
                      <dt>Service</dt>
                      <dd>
                        {report.shell.service || "none"}
                        {report.shell.restarts > 0 ? ` · ${report.shell.restarts} restarts` : ""}
                      </dd>
                      <dt>Models on disk</dt>
                      <dd>{report.shell.modelsOnDisk || "unknown"}</dd>
                      <dt>Disk free</dt>
                      <dd>{report.shell.diskFree || "unknown"}</dd>
                      {report.shell.gpu ? (
                        <>
                          <dt>GPU</dt>
                          <dd>{report.shell.gpu}</dd>
                        </>
                      ) : null}
                    </dl>
                  ) : null}
                  <ul className="findings">
                    {report.findings.map((finding, index) => (
                      <li key={index}>{finding}</li>
                    ))}
                  </ul>
                </div>
              ) : null}

              <div className="actions">
                <button
                  disabled={checking === server.id}
                  onClick={() => {
                    setChecking(server.id);
                    void client
                      .diagnoseServer(server.id)
                      .then((found) => setReports((prev) => ({ ...prev, [server.id]: found })))
                      .catch((err: unknown) =>
                        setError(err instanceof Error ? err.message : String(err)),
                      )
                      .finally(() => setChecking(null));
                  }}
                >
                  {checking === server.id ? "Checking…" : "Check"}
                </button>
                <button
                  className="secondary"
                  onClick={() => {
                    void client.removeServer(server.id).then(reload);
                  }}
                >
                  Remove
                </button>
              </div>
            </li>
          );
        })}
      </ul>

      {adding ? (
        <div className="project-form">
          <label className="field">
            What do you call it?
            <input
              value={draft.name}
              autoFocus
              onChange={(e) => setDraft({ ...draft, name: e.target.value })}
              placeholder="GPU Box"
            />
          </label>
          <label className="field">
            Where does the runtime answer?
            <input
              value={draft.baseUrl}
              onChange={(e) => setDraft({ ...draft, baseUrl: e.target.value })}
              placeholder="https://llm.example.com or http://192.168.1.20:11434"
            />
          </label>
          <label className="field">
            Can it also be reached by SSH? (optional)
            <select
              value={draft.sshAlias}
              onChange={(e) => setDraft({ ...draft, sshAlias: e.target.value })}
            >
              <option value="">No — manage models only</option>
              {aliases.map((host) => (
                <option key={host.alias} value={host.alias}>
                  {host.alias} — {host.user ? `${host.user}@` : ""}
                  {host.hostname}:{host.port}
                </option>
              ))}
            </select>
            <span className="field-note">
              {aliases.length === 0
                ? "No hosts in ~/.ssh/config. Add one there and it will appear here."
                : "Read from your own ~/.ssh/config. No key or password is stored."}
            </span>
          </label>
          <div className="actions">
            <button
              disabled={!draft.name.trim() || !draft.baseUrl.trim()}
              onClick={() => {
                void client
                  .addServer({
                    name: draft.name.trim(),
                    baseUrl: draft.baseUrl.trim(),
                    ...(draft.sshAlias ? { sshAlias: draft.sshAlias } : {}),
                  })
                  .then(() => {
                    setAdding(false);
                    setDraft({ name: "", baseUrl: "", sshAlias: "" });
                    return reload();
                  })
                  .catch((err: unknown) =>
                    setError(err instanceof Error ? err.message : String(err)),
                  );
              }}
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
          Add a server elsewhere…
        </button>
      )}
    </Dialog>
  );
}
