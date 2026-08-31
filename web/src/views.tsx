import { useCallback, useEffect, useState } from "react";
import type {
  ConnectorSummary,
  OpenCliClient,
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

export function ConnectorsView({ client }: { client: OpenCliClient }) {
  const { rows, error, loading } = useRemote<ConnectorSummary>(
    () => client.listConnectors(),
    [client],
  );

  return (
    <Panel
      title="Connectors"
      subtitle="MCP servers this session can call tools through"
      loading={loading}
      error={error}
      empty={rows.length === 0}
    >
      <ul className="rows">
        {rows.map((connector) => (
          <li key={connector.name}>
            <strong>{connector.name}</strong>
            <span>
              {connector.toolCount} tool{connector.toolCount === 1 ? "" : "s"} · {connector.status}
            </span>
          </li>
        ))}
      </ul>
      {!loading && rows.length === 0 ? (
        <p className="muted">
          Add servers under <code>[mcp_servers]</code> in <code>config.toml</code>.
        </p>
      ) : null}
    </Panel>
  );
}

export function SettingsView({ client }: { client: OpenCliClient }) {
  const [config, setConfig] = useState<Record<string, unknown> | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    client
      .readConfig()
      .then((value) => {
        if (!cancelled) setConfig(value);
      })
      .catch((err: unknown) => {
        if (!cancelled) setError(err instanceof Error ? err.message : String(err));
      });
    return () => {
      cancelled = true;
    };
  }, [client]);

  return (
    <section className="panel">
      <h2>Settings</h2>
      <p className="hint">
        The effective configuration after layering. Edit <code>~/.opencli/config.toml</code> to
        change it.
      </p>
      {error ? <p className="error">{error}</p> : null}
      {config ? (
        <pre className="config">{JSON.stringify(config, null, 2)}</pre>
      ) : error ? null : (
        <p className="muted">Loading…</p>
      )}
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
