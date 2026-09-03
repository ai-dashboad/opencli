import { useCallback, useEffect, useRef, useState } from "react";
import { FolderIcon, FolderPlusIcon, PinIcon, SearchIcon, SendIcon } from "./icons";
import { Dialog } from "./menus";
import { shouldDismiss, shouldSend } from "./composer";
import { isDesktop, revealPath } from "./host";
import type { UpdateState } from "./update";
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
  ModelOption,
  Appearance,
  TextSize,
  SecretStatus,
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
import { LOCALES, plural, t } from "./i18n";
import { scenariosNeeding } from "./scenarios";


/**
 * Skills: what the agent knows how to do here, and what else it could.
 *
 * This used to be two panels. "Skills" listed what was available in the
 * current directory and could not change any of it; "Plugins" installed the
 * same things from a short catalogue and called them something else. They are
 * one thing — a directory with instructions in it, read when a task calls for
 * one — and a person looking for "the thing that adds abilities" had to know
 * which of two words this project had chosen for which half.
 */
export function SkillsView({ client, cwd }: { client: OpenCliClient; cwd: string }) {
  const [rows, setRows] = useState<SkillSummary[]>([]);
  const [installed, setInstalled] = useState<InstalledPlugin[]>([]);
  const [offers, setOffers] = useState<PluginOffer[]>([]);
  const [tab, setTab] = useState<"yours" | "discover">("yours");
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [custom, setCustom] = useState({ name: "", source: "" });

  const reload = useCallback(async () => {
    try {
      const [skills, plugins, catalogued] = await Promise.all([
        client.listSkills(cwd),
        client.listPlugins().catch(() => [] as InstalledPlugin[]),
        client.pluginCatalog().catch(() => [] as PluginOffer[]),
      ]);
      setRows(skills);
      setInstalled(plugins);
      setOffers(catalogued);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, [client, cwd]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const toggle = useCallback(
    async (skill: SkillSummary, enabled: boolean) => {
      // Moved in the list first: the write is a round trip, and a switch that
      // waits for it feels broken.
      setRows((previous) =>
        previous.map((row) => (row.path === skill.path ? { ...row, enabled } : row)),
      );
      try {
        await client.setSkillEnabled(skill.path, enabled);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        await reload();
      }
    },
    [client, reload],
  );

  const install = useCallback(
    async (name: string, source: string) => {
      setBusy(name);
      setNote(null);
      try {
        const result = await client.installPlugin(name, source);
        setNote(
          result.loadable
            ? t("Installed {name}. It is available in new chats.", { name: result.name })
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
  const matches = (name: string, description: string) =>
    !needle ||
    name.toLowerCase().includes(needle) ||
    description.toLowerCase().includes(needle);

  const shownSkills = rows.filter((skill) => matches(skill.name, skill.description));

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Skills")}</h2>
        <span className="grow" />
        <input
          className="panel-search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={t("Search skills")}
        />
      </div>
      <p className="hint">
        {t("Reusable instructions the agent draws on when a task calls for one. Changes apply to the next chat you open.")}
      </p>

      <div className="tabs">
        <button className={tab === "yours" ? "on" : ""} onClick={() => setTab("yours")}>
          {t("Available here")}
        </button>
        <button className={tab === "discover" ? "on" : ""} onClick={() => setTab("discover")}>
          {t("Add more")}
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {note ? <p className="field-note">{note}</p> : null}
      {loading ? <p className="muted">{t("Loading…")}</p> : null}

      {tab === "yours" ? (
        <ul className="rows wide">
          {!loading && shownSkills.length === 0 ? (
            <li className="muted">
              {needle ? t("Nothing matches.") : t("No skills are available in {directory}.", { directory: cwd })}
            </li>
          ) : null}
          {shownSkills.map((skill) => (
            <li key={skill.path}>
              <strong>{skill.name}</strong>
              {/* Two lines unless opened. A skill's description is the prose
                  that tells the model when to reach for it, and at full length
                  five of them fill a screen — burying the names, which is what
                  the list is for. */}
              <span
                className={expanded === skill.path ? undefined : "clamped"}
                style={{ cursor: "pointer" }}
                onClick={() => setExpanded(expanded === skill.path ? null : skill.path)}
              >
                {skill.description}
              </span>
              <span className="source">{shortPath(skill.path)}</span>
              <div className="actions">
                <label className="scope">
                  <input
                    type="checkbox"
                    checked={skill.enabled}
                    onChange={(e) => void toggle(skill, e.target.checked)}
                  />
                  {t("Enabled")}
                </label>
                {installed.some((plugin) => plugin.name === skill.name) ? (
                  <button
                    className="secondary"
                    onClick={() => void client.removePlugin(skill.name).then(reload)}
                  >
                    {t("Uninstall")}
                  </button>
                ) : null}
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <>
          <ul className="cards">
            {offers
              .filter((offer) => matches(offer.name, offer.description))
              .map((offer) => {
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

          <h3>{t("Install from a repository")}</h3>
          <p className="hint">
            Cloned into <code>{t("~/.opencli/skills")}</code>{t(". There is no marketplace behind this — it is a git clone, and the repository is whatever you point it at.")}
          </p>
          <div className="task-form">
            <input
              value={custom.name}
              onChange={(e) => setCustom({ ...custom, name: e.target.value })}
              placeholder={t("Name")}
            />
            <input
              value={custom.source}
              onChange={(e) => setCustom({ ...custom, source: e.target.value })}
              placeholder={t("https://github.com/owner/repo")}
            />
            <button
              disabled={!custom.name.trim() || !custom.source.trim() || busy !== null}
              onClick={() => {
                void install(custom.name.trim(), custom.source.trim()).then(() =>
                  setCustom({ name: "", source: "" }),
                );
              }}
            >
              {t("Install")}
            </button>
          </div>
        </>
      )}
    </section>
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
  const [secrets, setSecrets] = useState<SecretStatus[]>([]);
  const [testing, setTesting] = useState(false);
  const [tested, setTested] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [draft, setDraft] = useState({ name: "", kind: "stdio", command: "", url: "", envVars: "" });
  /** Which variable is being given a value, and what has been typed. */
  const [keyFor, setKeyFor] = useState<string | null>(null);
  const [keyDraft, setKeyDraft] = useState("");

  const reload = useCallback(async () => {
    try {
      const [rows, catalogued] = await Promise.all([
        client.listConnectorConfigs(),
        client.connectorCatalog(),
      ]);
      const wanted = rows.flatMap((row) => row.transport.envVars ?? []);
      setConfigured(rows);
      setOffers(catalogued);
      setSecrets(await client.listSecrets(wanted).catch(() => [] as SecretStatus[]));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  /**
   * Starting every configured server and waiting for a handshake takes
   * seconds — measured at 2.2 against one that fails to authenticate — so it
   * happens when asked for, not every time the panel is opened.
   */
  const test = useCallback(async () => {
    setTesting(true);
    try {
      setStatus(await client.listConnectors());
      setTested(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setTesting(false);
    }
  }, [client]);

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

  const saveKey = useCallback(
    async (name: string) => {
      try {
        await client.writeSecret(name, keyDraft);
        setKeyFor(null);
        setKeyDraft("");
        await reload();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
    },
    [client, keyDraft, reload],
  );

  const hasKey = useCallback(
    (name: string) => secrets.some((secret) => secret.name === name),
    [secrets],
  );

  const addManual = useCallback(() => {
    const names = draft.envVars
      .split(/[\s,]+/)
      .map((name) => name.trim().toUpperCase())
      .filter(Boolean);
    const transport =
      draft.kind === "http"
        ? { kind: "http" as const, url: draft.url.trim() }
        : {
            kind: "stdio" as const,
            command: draft.command.trim().split(/\s+/)[0] ?? "",
            args: draft.command.trim().split(/\s+/).slice(1),
            envVars: names,
          };
    void run(
      client.addConnector({ name: draft.name.trim(), transport }).then(() => {
        setAdding(false);
        setDraft({ name: "", kind: "stdio", command: "", url: "", envVars: "" });
      }),
    );
  }, [client, draft, run]);

  const notYetAdded = offers.filter(
    (offer) => !configured.some((row) => row.name === offer.id || row.name === offer.name),
  );

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Connectors")}</h2>
        <span className="grow" />
        <button className="secondary" disabled={testing} onClick={() => void test()}>
          {testing ? t("Starting them…") : t("Test connections")}
        </button>
      </div>
      <p className="hint">
        {t("MCP servers the agent can call tools through. Servers start with a chat, so a change here applies to the next one you open.")}
      </p>
      {error ? <p className="error">{error}</p> : null}

      <h3>{t("Configured")}</h3>
      <ul className="rows wide">
        {configured.length === 0 ? <li className="muted">{t("None yet.")}</li> : null}
        {configured.map((row) => {
          const live = status.find((entry) => entry.name === row.name);
          const needs = row.transport.envVars ?? [];
          // Read the other way round. A row that says `shopify` and lists its
          // transport says what the thing is; it never said why anyone would
          // want it, which is the question people arrive with.
          const unlocks = scenariosNeeding(row.name);
          return (
            <li key={row.name}>
              <strong>{row.name}</strong>
              <span>
                {row.transport.kind === "http"
                  ? row.transport.url
                  : [row.transport.command, ...(row.transport.args ?? [])].join(" ")}
              </span>

              {unlocks.length > 0 ? (
                <span className="unlocks">
                  {t("Used for")} {unlocks.map((scenario) => scenario.name()).join(" · ")}
                </span>
              ) : null}

              {needs.length > 0 ? (
                <span>
                  {needs.map((name) => (
                    <em key={name} className={hasKey(name) ? "chip-ok" : "chip-missing"}>
                      {name}
                      {hasKey(name) ? " set" : " missing"}
                    </em>
                  ))}
                </span>
              ) : null}

              {live ? (
                <span>
                  {live.status} · {plural(live.toolCount, "{count} tool", "{count} tools")}
                  {live.tools.length > 0 ? (
                    <button
                      className="link"
                      onClick={() => setExpanded(expanded === row.name ? null : row.name)}
                    >
                      {expanded === row.name ? "hide" : "show"}
                    </button>
                  ) : null}
                </span>
              ) : tested ? (
                <span className="muted-note">{t("Did not answer.")}</span>
              ) : null}

              {expanded === row.name && live ? (
                <pre className="config">{live.tools.join("\n")}</pre>
              ) : null}

              {needs.map((name) =>
                keyFor === name ? (
                  <div className="actions" key={`edit-${name}`}>
                    <input
                      type="password"
                      autoFocus
                      value={keyDraft}
                      placeholder={`Paste ${name}`}
                      onChange={(e) => setKeyDraft(e.target.value)}
                    />
                    <button disabled={!keyDraft.trim()} onClick={() => void saveKey(name)}>
                      {t("Save")}
                    </button>
                    <button className="secondary" onClick={() => setKeyFor(null)}>
                      {t("Cancel")}
                    </button>
                  </div>
                ) : null,
              )}

              <div className="actions">
                <label className="scope">
                  <input
                    type="checkbox"
                    checked={row.enabled}
                    onChange={(e) => void run(client.setConnectorEnabled(row.name, e.target.checked))}
                  />
                  {t("Enabled")}
                </label>
                {needs.map((name) => (
                  <button
                    key={`set-${name}`}
                    className="secondary"
                    onClick={() => {
                      setKeyFor(name);
                      setKeyDraft("");
                    }}
                  >
                    {hasKey(name) ? `Replace ${name}` : `Set ${name}`}
                  </button>
                ))}
                <button className="secondary" onClick={() => void run(client.removeConnector(row.name))}>
                  {t("Remove")}
                </button>
              </div>
            </li>
          );
        })}
      </ul>

      <h3>{t("Add a connector")}</h3>
      <ul className="rows wide">
        {notYetAdded.map((offer) => (
          <li key={offer.id}>
            <strong>{offer.name}</strong>
            <span>{offer.description}</span>
            {offer.note ? <span className="muted-note">{offer.note}</span> : null}
            <div className="actions">
              <button
                onClick={() =>
                  void run(client.addConnector({ name: offer.id, transport: offer.transport }))
                }
              >
                {t("Add")}
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
            placeholder={t("Name (letters, digits, - and _)")}
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
                      ? t("A program on this machine, started by OpenCLI.")
                      : t("A server reachable over HTTP.")}
                  </span>
                </span>
              </label>
            ))}
          </div>
          {draft.kind === "stdio" ? (
            <>
              <input
                value={draft.command}
                onChange={(e) => setDraft({ ...draft, command: e.target.value })}
                placeholder={t("npx -y @modelcontextprotocol/server-github")}
              />
              <label className="field">
                {t("Environment variables it needs")}
                <input
                  value={draft.envVars}
                  onChange={(e) => setDraft({ ...draft, envVars: e.target.value })}
                  placeholder={t("GITHUB_PERSONAL_ACCESS_TOKEN")}
                />
                <span className="field-note">
                  {t("Names only, separated by spaces. Values are set afterwards and kept with your other keys, not in the connector's configuration.")}
                </span>
              </label>
            </>
          ) : (
            <input
              value={draft.url}
              onChange={(e) => setDraft({ ...draft, url: e.target.value })}
              placeholder={t("https://example.com/mcp")}
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
              {t("Add")}
            </button>
            <button className="secondary" onClick={() => setAdding(false)}>
              {t("Cancel")}
            </button>
          </div>
        </div>
      ) : (
        <button className="secondary" onClick={() => setAdding(true)}>
          {t("Add another…")}
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

/** The permission choices, worded as consequences rather than as settings. */
const APPROVAL_SETTINGS: { value: string; label: string; hint: string }[] = [
  {
    value: "untrusted",
    label: t("Ask before anything unfamiliar"),
    hint: t("Every command that is not known-safe is shown to you first."),
  },
  {
    value: "on-failure",
    label: t("Ask only after something fails"),
    hint: t("Commands run unattended; you are asked when one needs more access."),
  },
  {
    value: "never",
    label: t("Never ask"),
    hint: t("The agent runs commands on this machine without stopping."),
  },
];

const SANDBOX_SETTINGS: { value: string; label: string; hint: string }[] = [
  {
    value: "read-only",
    label: t("Read only"),
    hint: t("The agent can look at files but not change them."),
  },
  {
    value: "workspace-write",
    label: t("Write in the working directory"),
    hint: t("Edits are confined to the folder the chat is open in."),
  },
  {
    value: "danger-full-access",
    label: t("No sandbox"),
    hint: t("Anything your account can do, the agent can do."),
  },
];

/**
 * Settings: the handful of things worth changing, and the file underneath.
 *
 * It used to be read-only — a flattened dump of the configuration with a line
 * at the bottom saying to edit `config.toml` by hand. That is a fine answer for
 * someone who already has a terminal open and a model configured, and no answer
 * at all for the person this panel exists for: an app opened from a dock icon,
 * with no provider set up and nowhere to put a key.
 *
 * So: the settings that decide whether the thing works at all, edited here; and
 * the rest still shown, still read-only, still saying which file set it.
 */
export function SettingsView({
  client,
  version,
  update,
}: {
  client: OpenCliClient;
  /** The running app's version; absent in the browser build. */
  version: string | null;
  /** Present only in the desktop build, which is the only one that updates. */
  update?: UpdateState;
}) {
  const [result, setResult] = useState<Record<string, unknown> | null>(null);
  const [models, setModels] = useState<ModelOption[]>([]);
  const [secrets, setSecrets] = useState<SecretStatus[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const [keyDraft, setKeyDraft] = useState("");
  const [newKeyName, setNewKeyName] = useState("");

  const reload = useCallback(async () => {
    try {
      const config = await client.readConfig();
      // Which variables to ask about: the ones the configured providers say
      // they read a key from. Anything else in the environment is somebody
      // else's business.
      const providers = (config.config as Record<string, unknown> | undefined)?.[
        "model_providers"
      ];
      const wanted = Object.values((providers ?? {}) as Record<string, unknown>)
        .map((provider) => (provider as Record<string, unknown>)?.env_key)
        .filter((key): key is string => typeof key === "string" && key.length > 0);

      const [available, keys] = await Promise.all([
        client.listModels().catch(() => [] as ModelOption[]),
        client.listSecrets(wanted).catch(() => [] as SecretStatus[]),
      ]);
      setResult(config);
      setModels(available);
      setSecrets(keys);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const config = (result?.config ?? {}) as Record<string, unknown>;
  const origins = (result?.origins ?? {}) as Record<string, unknown>;
  const entries = flatten(config);
  // A null here means "not set in any file", not "set to nothing" — the
  // built-in default applies. Showing hundreds of them buries the few that
  // were actually configured.
  const set = entries.filter(([, value]) => value !== null && value !== undefined);

  /** Write one value and say so, briefly. */
  const put = useCallback(
    async (keyPath: string, value: unknown, what: string) => {
      try {
        await client.writeConfigValue(keyPath, value);
        setSaved(`${what} saved. It applies to the next chat you open.`);
        setError(null);
        await reload();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
    },
    [client, reload],
  );

  const saveKey = useCallback(
    async (name: string, value: string | null) => {
      try {
        await client.writeSecret(name, value);
        setEditingKey(null);
        setKeyDraft("");
        setNewKeyName("");
        setSaved(value === null ? `${name} removed.` : `${name} saved.`);
        setError(null);
        await reload();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
    },
    [client, reload],
  );

  const currentModel = typeof config.model === "string" ? config.model : "";
  const currentApproval =
    typeof config.approval_policy === "string" ? config.approval_policy : "untrusted";
  const currentSandbox =
    typeof config.sandbox_mode === "string" ? config.sandbox_mode : "workspace-write";

  return (
    <section className="panel">
      <h2>{t("Settings")}</h2>
      {error ? <p className="error">{error}</p> : null}
      {saved ? <p className="field-note">{saved}</p> : null}
      {!result && !error ? <p className="muted">{t("Loading…")}</p> : null}

      <h3>{t("Default model")}</h3>
      <p className="hint">
        {t("Used by new chats. A chat can still be switched to another model while it is open.")}
      </p>
      {models.length === 0 ? (
        <p className="muted">
          No models are configured yet. Add one under <strong>{t("Models")}</strong>, or declare a
          provider in <code>{t("config.toml")}</code>.
        </p>
      ) : (
        <label className="sort">
          {t("Model")}
          <select
            value={currentModel}
            onChange={(e) => void put("model", e.target.value, "Default model")}
          >
            <option value="">{t("Not set")}</option>
            {models.map((model) => (
              <option key={model.id} value={model.model}>
                {model.displayName || model.model}
              </option>
            ))}
          </select>
        </label>
      )}

      <h3>{t("API keys")}</h3>
      <p className="hint">
        {t(
          "Kept in {file}, not in {other} — that file gets shared and pasted into issues. Values are never shown again once saved.",
          { file: "~/.opencli/.env", other: "config.toml" },
        )}
      </p>
      <ul className="rows">
        {secrets.length === 0 ? <li className="muted">{t("No keys set.")}</li> : null}
        {secrets.map((secret) => (
          <li key={secret.name}>
            <strong>{secret.name}</strong>
            <span>
              {secret.fromEnvironment
                ? "set in your shell environment, which takes precedence"
                : "•••••••• stored"}
            </span>
            {editingKey === secret.name ? (
              <div className="actions">
                <input
                  type="password"
                  value={keyDraft}
                  autoFocus
                  placeholder={t("Paste the new key")}
                  onChange={(e) => setKeyDraft(e.target.value)}
                />
                <button disabled={!keyDraft.trim()} onClick={() => void saveKey(secret.name, keyDraft)}>
                  {t("Save")}
                </button>
                <button className="secondary" onClick={() => setEditingKey(null)}>
                  {t("Cancel")}
                </button>
              </div>
            ) : (
              <div className="actions">
                <button className="secondary" onClick={() => setEditingKey(secret.name)}>
                  {t("Replace")}
                </button>
                {secret.stored ? (
                  <button className="secondary" onClick={() => void saveKey(secret.name, null)}>
                    {t("Remove")}
                  </button>
                ) : null}
              </div>
            )}
          </li>
        ))}
      </ul>
      <div className="task-form">
        <input
          value={newKeyName}
          placeholder={t("OPENAI_API_KEY")}
          onChange={(e) => setNewKeyName(e.target.value.toUpperCase())}
        />
        <input
          type="password"
          value={editingKey === null ? keyDraft : ""}
          placeholder={t("Paste the key")}
          onChange={(e) => {
            setEditingKey(null);
            setKeyDraft(e.target.value);
          }}
        />
        <button
          disabled={!newKeyName.trim() || !keyDraft.trim()}
          onClick={() => void saveKey(newKeyName.trim(), keyDraft)}
        >
          {t("Add")}
        </button>
      </div>

      <h3>{t("When to ask permission")}</h3>
      <div className="choices">
        {APPROVAL_SETTINGS.map((option) => (
          <label key={option.value} className="choice">
            <input
              type="radio"
              name="approval-setting"
              checked={currentApproval === option.value}
              onChange={() => void put("approval_policy", option.value, "Permission setting")}
            />
            <span>
              <strong>{option.label}</strong>
              <span className="hint">{option.hint}</span>
            </span>
          </label>
        ))}
      </div>

      <h3>{t("What it may change")}</h3>
      <div className="choices">
        {SANDBOX_SETTINGS.map((option) => (
          <label key={option.value} className="choice">
            <input
              type="radio"
              name="sandbox-setting"
              checked={currentSandbox === option.value}
              onChange={() => void put("sandbox_mode", option.value, "Sandbox setting")}
            />
            <span>
              <strong>{option.label}</strong>
              <span className="hint">{option.hint}</span>
            </span>
          </label>
        ))}
      </div>

      <h3>{t("About")}</h3>
      <ul className="rows">
        <li>
          <strong>{t("Version")}</strong>
          <span>{version ?? "running in a browser"}</span>
          {update ? (
            <div className="actions">
              {update.stage === "available" ? (
                <button onClick={update.install}>Update to {update.version}</button>
              ) : update.stage === "ready" ? (
                <button onClick={update.restart}>Restart into {update.version}</button>
              ) : update.stage === "downloading" ? (
                <span className="muted-note">Downloading {update.version}…</span>
              ) : (
                <span className="muted-note">{t("Up to date.")}</span>
              )}
            </div>
          ) : null}
        </li>
        <li>
          <strong>{t("Configuration")}</strong>
          <span>{t("~/.opencli/config.toml")}</span>
        </li>
        <li>
          <strong>{t("Logs")}</strong>
          <span>{t("~/.opencli/log")}</span>
        </li>
      </ul>

      {result ? (
        <>
          <h3>{t("Everything your files set")}</h3>
          <p className="hint">
            {t(
              "Read-only. Anything not listed uses the built-in default. Values come from {file} unless another file is named.",
              { file: "~/.opencli/config.toml" },
            )}
          </p>
          {set.length === 0 ? (
            <p className="muted">{t("Nothing configured; all defaults are in use.")}</p>
          ) : null}
          {groupSettings(set).map(([section, rows]) => (
            <div className="setting-group" key={section}>
              <h4>{section === "" ? t("General") : section}</h4>
              <dl className="setting-list">
                {rows.map(([path, leaf, value]) => {
                  const file = originFile(origins, path);
                  return (
                    <div key={path}>
                      <dt>{leaf}</dt>
                      <dd>
                        <code>{JSON.stringify(value)}</code>
                        {/* Named only when it is not the file the heading
                            already said everything comes from. Repeating the
                            same path under every value turned a settings list
                            into a column of one path. */}
                        {file && !isMainConfig(file) ? (
                          <span className="source">{shortPath(file)}</span>
                        ) : null}
                      </dd>
                    </div>
                  );
                })}
              </dl>
            </div>
          ))}

          <button className="secondary" onClick={() => setShowAll(!showAll)}>
            {showAll ? t("Hide raw config") : t("Show raw config ({count} keys)", { count: entries.length })}
          </button>
          {showAll ? <pre className="config">{JSON.stringify(config, null, 2)}</pre> : null}
        </>
      ) : null}
    </section>
  );
}


/**
 * Group flattened settings by the section they belong to.
 *
 * `profiles.huihui.model_context_window` is unreadable as a row of its own and
 * obvious under a heading that says `profiles.huihui`. Top-level keys — `model`,
 * `approval_policy` — have no section and are collected first, because they are
 * the ones anyone came here to look at.
 *
 * Returns `[section, [fullPath, leafKey, value]]`, keeping the full path so a
 * row can still be traced back to its origin.
 */
function groupSettings(
  entries: [string, unknown][],
): [string, [string, string, unknown][]][] {
  const groups = new Map<string, [string, string, unknown][]>();
  for (const [path, value] of entries) {
    const parts = path.split(".");
    const leaf = parts.pop() ?? path;
    const section = parts.join(".");
    const rows = groups.get(section) ?? [];
    rows.push([path, leaf, value]);
    groups.set(section, rows);
  }
  // Top-level first, then sections in alphabetical order.
  return [...groups.entries()].sort(([left], [right]) => {
    if (left === "") return -1;
    if (right === "") return 1;
    return left.localeCompare(right);
  });
}

/** Whether a value came from the config file the heading already named. */
function isMainConfig(file: string): boolean {
  return file.endsWith("/.opencli/config.toml") || file.endsWith("\\.opencli\\config.toml");
}

/**
 * A path without the home directory in it.
 *
 * Both because it is shorter and because this panel ends up in screenshots,
 * and a home directory is somebody's name.
 */
function shortPath(file: string): string {
  return file.replace(/^\/(?:Users|home)\/[^/]+/, "~").replace(/^C:\\Users\\[^\\]+/i, "~");
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

const INTERVAL_UNITS: { value: string; label: string }[] = [
  { value: "m", label: t("minutes") },
  { value: "h", label: t("hours") },
  { value: "d", label: t("days") },
];

export function ScheduledView({
  client,
  cwd,
  onBrowse,
}: {
  client: OpenCliClient;
  cwd: string;
  /** Opens the platform folder chooser; absent in the browser build. */
  onBrowse?: (start: string) => Promise<string | null>;
}) {
  const [tasks, setTasks] = useState<ScheduledTask[]>([]);
  const [runs, setRuns] = useState<Run[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [prompt, setPrompt] = useState("");
  const [every, setEvery] = useState("1");
  const [unit, setUnit] = useState("h");
  const [directory, setDirectory] = useState(cwd);
  const [expanded, setExpanded] = useState<string | null>(null);

  const reload = useCallback(async () => {
    try {
      const [listed, recent] = await Promise.all([
        client.listTasks(),
        client.listRuns({ limit: 100 }).catch(() => [] as Run[]),
      ]);
      setTasks(listed);
      setRuns(recent);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  // A task that was just told to run appears in the list seconds later, so the
  // panel keeps looking while it is open.
  useEffect(() => {
    const timer = setInterval(() => void reload(), 6000);
    return () => clearInterval(timer);
  }, [reload]);

  useEffect(() => {
    setDirectory((current) => current || cwd);
  }, [cwd]);

  const add = useCallback(async () => {
    const seconds = parseInterval(`${every}${unit}`);
    if (!seconds) {
      setError(t("How often must be a whole number greater than zero."));
      return;
    }
    try {
      await client.createTask({
        name: name.trim() || prompt.trim().slice(0, 40),
        prompt: prompt.trim(),
        intervalSeconds: seconds,
        cwd: directory || cwd,
      });
      setName("");
      setPrompt("");
      await reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client, cwd, directory, every, name, prompt, reload, unit]);

  return (
    <section className="panel">
      <h2>{t("Scheduled tasks")}</h2>
      <p className="hint">
        {t("Prompts that run on a repeat. They run only while OpenCLI is open — this is a local agent, not a server.")}
      </p>
      {error ? <p className="error">{error}</p> : null}

      <div className="project-form">
        <label className="field">
          What should it do?
          <textarea
            value={prompt}
            rows={2}
            onChange={(e) => setPrompt(e.target.value)}
            placeholder={t("Check the build and summarise anything that broke")}
          />
        </label>
        <label className="field">
          {t("Name (optional)")}
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder={t("Build check")} />
        </label>
        <label className="field">
          {t("How often")}
          <span className="path-input">
            <input
              className="interval"
              type="number"
              min="1"
              value={every}
              onChange={(e) => setEvery(e.target.value)}
            />
            <select value={unit} onChange={(e) => setUnit(e.target.value)}>
              {INTERVAL_UNITS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </span>
        </label>
        <label className="field">
          {t("Where to run")}
          <span className="path-input">
            <input
              value={directory}
              onChange={(e) => setDirectory(e.target.value)}
              placeholder={t("/path/to/project")}
            />
            {onBrowse ? (
              <button
                type="button"
                className="ghost"
                onClick={() => {
                  void onBrowse(directory || cwd).then((picked) => {
                    if (picked) setDirectory(picked);
                  });
                }}
              >
                <FolderPlusIcon size={14} />
                {t("Choose")}
              </button>
            ) : null}
          </span>
        </label>
        <div className="actions">
          <button onClick={() => void add()} disabled={!prompt.trim()}>
            {t("Add task")}
          </button>
        </div>
      </div>

      <ul className="rows wide">
        {tasks.length === 0 ? <li className="muted">{t("No tasks yet.")}</li> : null}
        {tasks.map((task) => {
          const history = runs.filter((run) => run.taskId === task.id);
          const last = history[0];
          return (
            <li key={task.id}>
              <strong>{task.name}</strong>
              <span>{task.prompt}</span>
              <span>
                {describeInterval(task.intervalSeconds)} · next {describeWhen(task.nextRun)} ·{" "}
                {task.enabled ? "active" : "paused"}
                {last ? ` · ${t("last run {status}", { status: STATUS_LABEL[last.status]().toLowerCase() })}` : " · never run"}
              </span>
              <div className="actions">
                <button
                  className="secondary"
                  onClick={() => {
                    void client
                      .runTaskNow(task.id)
                      .then(reload)
                      .catch((err: unknown) =>
                        setError(err instanceof Error ? err.message : String(err)),
                      );
                  }}
                >
                  {t("Run now")}
                </button>
                <button
                  className="secondary"
                  onClick={() => {
                    void client.setTaskEnabled(task.id, !task.enabled).then(reload);
                  }}
                >
                  {task.enabled ? t("Pause") : t("Resume")}
                </button>
                {history.length > 0 ? (
                  <button
                    className="secondary"
                    onClick={() => setExpanded(expanded === task.id ? null : task.id)}
                  >
                    {expanded === task.id ? "Hide runs" : `Runs (${history.length})`}
                  </button>
                ) : null}
                <button
                  className="secondary"
                  onClick={() => {
                    void client.deleteTask(task.id).then(reload);
                  }}
                >
                  {t("Delete")}
                </button>
              </div>

              {expanded === task.id ? (
                <ul className="rows">
                  {history.map((run) => (
                    <li key={run.id}>
                      <strong>
                        {STATUS_LABEL[run.status]()} · {ago(run.finishedAt ?? run.startedAt)}
                      </strong>
                      {run.output ? <pre className="run-output">{run.output}</pre> : null}
                    </li>
                  ))}
                </ul>
              ) : null}
            </li>
          );
        })}
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
  { value: "updated", label: t("Last updated") },
  { value: "created", label: t("Date created") },
  { value: "name", label: t("Name") },
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
  onChanged,
  onBrowse,
}: {
  client: OpenCliClient;
  onOpen: (project: Project) => void;
  /** Told whenever the list is written to, so the sidebar can catch up. */
  onChanged?: () => void;
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

  /** After a write: this page and the sidebar must agree on what exists. */
  const written = useCallback(async () => {
    await reload();
    onChanged?.();
  }, [onChanged, reload]);

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
      await written();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client, close, draft, editing, written]);

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
        <h2 className="display">{t("Projects")}</h2>
        <span className="grow" />
        {searching ? (
          <input
            className="panel-search"
            value={query}
            autoFocus
            placeholder={t("Search projects")}
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
            aria-label={t("Search projects")}
            onClick={() => setSearching(true)}
          >
            <SearchIcon size={15} />
          </button>
        )}
        <label className="sort">
          {t("Sort by")}
          <select value={sort} onChange={(e) => setSort(e.target.value as ProjectSort)}>
            {SORTS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <button className="filled" onClick={() => setComposing(true)}>
          {t("New project")}
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}

      <Dialog
        open={composing}
        title={editing ? t("Edit project") : t("Create a project")}
        onClose={close}
        footer={
          <>
            <button className="secondary" onClick={close}>
              {t("Cancel")}
            </button>
            <button className="filled" onClick={() => void save()} disabled={!canSave}>
              {editing ? t("Save changes") : t("Create project")}
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
            placeholder={t("Name your project")}
          />
        </label>

        <label className="field">
          What are you trying to achieve?
          <textarea
            value={draft.description}
            onChange={(e) => setDraft({ ...draft, description: e.target.value })}
            placeholder={t("Describe your project, goals, subject…")}
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
              placeholder={t("/path/to/project")}
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
                {t("Use a folder")}
              </button>
            ) : null}
          </span>
          {!editing && draft.cwd && !pathTouched ? (
            <span className="field-note">
              {t("This folder will be created if it does not exist.")}
            </span>
          ) : null}
        </label>

        <details className="more-field">
          <summary>{t("Standing instructions (optional)")}</summary>
          <p className="hint">
            {t("Given to the agent in every chat here — how to build it, what not to touch. Separate from the description above, which only you read.")}
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
          {query ? t("Nothing matches.") : t("No projects yet. Create one to group chats by directory.")}
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
                aria-label={project.pinned ? t("Unpin") : t("Pin")}
                title={project.pinned ? t("Unpin") : t("Pin to the top")}
                onClick={() => {
                  void client
                    .updateProject(project.id, { pinned: !project.pinned })
                    .then(written);
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
                {plural(project.threadIds.length, "{count} chat", "{count} chats")}
              </span>
            </div>

            <div className="card-hover">
              <button className="secondary" onClick={() => edit(project)}>
                {t("Edit")}
              </button>
              <button
                className="secondary"
                onClick={() => {
                  void client.deleteProject(project.id).then(written);
                }}
              >
                {t("Delete")}
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
      <h2>{t("Artifacts")}</h2>
      <p className="hint">
        {t("Files the agent edited in this conversation. The changes are already on disk — this is here so you can check them without leaving.")}
      </p>
      <ul className="rows wide">
        {rows.length === 0 ? (
          <li className="muted">
            <p style={{ margin: 0 }}>{t("Nothing edited in this conversation.")}</p>
            {/* Said plainly rather than left as a puzzle: a model that writes
                files by running `cat > file` has still written them, and an
                empty panel after watching it do that reads as a broken panel
                rather than as a limit of what is recorded. */}
            <p className="hint" style={{ marginBottom: 0 }}>
              {t(
                "Only edits made with the agent's file-editing tool are listed here. Files written by a shell command it ran — a heredoc, a script, git checkout — are not tracked, and will not appear.",
              )}
            </p>
          </li>
        ) : null}
        {rows.map((change) => (
          <li key={change.path}>
            <strong title={change.path}>{shortPath(change.path)}</strong>
            <span>{change.kind}</span>
            <div className="actions">
              <button
                className="secondary"
                onClick={() => setOpenPath(openPath === change.path ? null : change.path)}
              >
                {openPath === change.path
                  ? t("Hide")
                  : change.kind === "update"
                    ? t("Show diff")
                    : t("Show file")}
              </button>
              {isDesktop() && change.kind !== "delete" ? (
                <button className="secondary" onClick={() => revealPath(change.path)}>
                  Show in {onMac() ? t("Finder") : "folder"}
                </button>
              ) : null}
            </div>
            {openPath === change.path ? <ChangeBody change={change} /> : null}
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Name the file manager the way the platform's own menus do. */
function onMac(): boolean {
  return navigator.userAgent.includes("Mac");
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
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState<string | null>(null);
  const [draft, setDraft] = useState("");

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

  const save = useCallback(
    async (id: string) => {
      const next = draft.trim();
      if (!next) return;
      try {
        await client.updateMemory(id, next);
        setEditing(null);
        setDraft("");
        await reload();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
    },
    [client, draft, reload],
  );

  const needle = query.trim().toLowerCase();
  const shown = needle
    ? memories.filter((memory) => memory.text.toLowerCase().includes(needle))
    : memories;

  // Grouped by what they apply to, because that is the only thing that changes
  // what a memory does. A flat list with a note on each row made the two look
  // like the same kind of thing.
  const everywhere = shown.filter((memory) => !memory.projectId);
  const scopedToProjects = shown.filter((memory) => memory.projectId);

  const row = (memory: Memory) => (
    <li key={memory.id}>
      {editing === memory.id ? (
        <>
          <textarea
            value={draft}
            autoFocus
            rows={2}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (shouldSend({ ...e, isComposing: e.nativeEvent.isComposing })) {
                e.preventDefault();
                void save(memory.id);
              }
            }}
          />
          <div className="actions">
            <button disabled={!draft.trim()} onClick={() => void save(memory.id)}>
              {t("Save")}
            </button>
            <button className="secondary" onClick={() => setEditing(null)}>
              {t("Cancel")}
            </button>
          </div>
        </>
      ) : (
        <>
          <strong>{memory.text}</strong>
          <span>about {estimateTokens(memory.text)} tokens in every chat it applies to</span>
          <div className="actions">
            <button
              className="secondary"
              onClick={() => {
                setEditing(memory.id);
                setDraft(memory.text);
              }}
            >
              {t("Edit")}
            </button>
            <button
              className="secondary"
              onClick={() => {
                void client.deleteMemory(memory.id).then(reload);
              }}
            >
              {t("Forget")}
            </button>
          </div>
        </>
      )}
    </li>
  );

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Memory")}</h2>
        <span className="grow" />
        {memories.length > 3 ? (
          <input
            className="panel-search"
            value={query}
            placeholder={t("Search memories")}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (shouldDismiss({ ...e, isComposing: e.nativeEvent.isComposing })) setQuery("");
            }}
          />
        ) : null}
      </div>
      <p className="hint">
        {t("Facts the agent should always know. They are added to the context of every new chat, so keep the list short — each one costs tokens in every conversation.")}
      </p>
      {error ? <p className="error">{error}</p> : null}

      <div className="task-form">
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder={t("e.g. Deploy with `just ship`, never with npm")}
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
          {t("Remember")}
        </button>
      </div>

      <h3>{t("In every conversation")}</h3>
      <ul className="rows wide">
        {everywhere.length === 0 ? (
          <li className="muted">{needle ? "Nothing matches." : "Nothing remembered yet."}</li>
        ) : null}
        {everywhere.map(row)}
      </ul>

      {scopedToProjects.length > 0 ? (
        <>
          <h3>{t("In one project only")}</h3>
          <ul className="rows wide">{scopedToProjects.map(row)}</ul>
        </>
      ) : null}
    </section>
  );
}

/**
 * Roughly what a piece of text costs.
 *
 * Four characters to a token is the usual rule of thumb for English, and it is
 * shown here because the panel already asks the reader to keep the list short
 * without ever saying what short means.
 */
function estimateTokens(text: string): number {
  return Math.max(1, Math.round(text.length / 4));
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
    return <p className="error">{t("The contents of this change could not be read.")}</p>;
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
  { value: "pragmatic", label: t("Pragmatic"), hint: t("Terse. Answers, not commentary.") },
  { value: "friendly", label: t("Friendly"), hint: t("Warmer, more explanatory.") },
];

const EFFORTS: { value: ReasoningEffort; label: string }[] = [
  { value: "minimal", label: t("Minimal") },
  { value: "low", label: t("Low") },
  { value: "medium", label: t("Medium") },
  { value: "high", label: t("High") },
  { value: "xhigh", label: t("Highest") },
];

const POLICIES: { value: ApprovalPolicy; label: string; hint: string }[] = [
  {
    value: "untrusted",
    label: t("Ask before anything unfamiliar"),
    hint: t("Every command that is not known-safe is shown to you first."),
  },
  {
    value: "on-failure",
    label: t("Ask only after something fails"),
    hint: t("Commands run unattended; you are asked when one needs to retry with more access."),
  },
  {
    value: "never",
    label: t("Never ask"),
    hint: t("The agent runs commands on this machine without stopping. Only for a directory you would let a script loose in."),
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
const APPEARANCES: { value: Appearance; label: string; hint: string }[] = [
  { value: "system", label: t("Follow the system"), hint: t("Changes when your computer does.") },
  { value: "dark", label: t("Dark"), hint: t("Warm dark grey.") },
  { value: "light", label: t("Light"), hint: t("Warm off-white.") },
];

const TEXT_SIZES: { value: TextSize; label: string }[] = [
  { value: "normal", label: t("Normal") },
  { value: "large", label: t("Large") },
  { value: "larger", label: t("Larger") },
];

/**
 * Customize: how the agent works with you, and how it looks.
 *
 * `on-request` is deliberately not offered as an approval policy. It leaves
 * the decision to the model, which in practice almost never asks — so it reads
 * as "never" to anyone who picks it expecting to be consulted, which is the
 * wrong way for a security setting to be wrong.
 *
 * The toggles here are the same state the chat's own menus write to: this is
 * the full list, those are shortcuts to the two or three worth reaching
 * mid-conversation. They were only in the menus before, which meant a panel
 * called Customize did not contain most of what could be customised.
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
      <h2>{t("Customize")}</h2>
      <p className="hint">
        Kept on this computer. Most of it applies to chats you start from now on; the effort and
        the appearance apply straight away.
      </p>

      <h3>{t("Appearance")}</h3>
      <div className="choices">
        {APPEARANCES.map((option) => (
          <label key={option.value} className="choice">
            <input
              type="radio"
              name="appearance"
              checked={(preferences.appearance ?? "system") === option.value}
              onChange={() => onChange({ ...preferences, appearance: option.value })}
            />
            <span>
              <strong>{option.label}</strong>
              <span className="hint">{option.hint}</span>
            </span>
          </label>
        ))}
      </div>

      <h3>{t("Language")}</h3>
      <div className="choices">
        {/* Each language is named in itself, untranslated, so somebody who
            cannot read the language currently on screen can still find their
            own. Only "follow the system" is translated. */}
        <label className="choice">
          <input
            type="radio"
            name="language"
            checked={(preferences.language ?? "system") === "system"}
            onChange={() => onChange({ ...preferences, language: "system" })}
          />
          <span>
            <strong>{t("Follow the system")}</strong>
            <span className="hint">{t("Uses your browser's language.")}</span>
          </span>
        </label>
        {LOCALES.map((locale) => (
          <label key={locale.value} className="choice">
            <input
              type="radio"
              name="language"
              checked={preferences.language === locale.value}
              onChange={() => onChange({ ...preferences, language: locale.value })}
            />
            <span>
              <strong>{locale.label}</strong>
            </span>
          </label>
        ))}
      </div>

      <h3>{t("Text size")}</h3>
      <div className="choices">
        {TEXT_SIZES.map((option) => (
          <label key={option.value} className="choice">
            <input
              type="radio"
              name="text-size"
              checked={(preferences.textSize ?? "normal") === option.value}
              onChange={() => onChange({ ...preferences, textSize: option.value })}
            />
            <span>
              <strong>{option.label}</strong>
            </span>
          </label>
        ))}
      </div>

      <h3>{t("Tone")}</h3>
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

      <h3>{t("Thinking effort")}</h3>
      {available.length === 0 ? (
        <p className="muted">{t("The selected model does not take an effort setting.")}</p>
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

      <h3>{t("What to show")}</h3>
      <ul className="rows">
        <li>
          <strong>{t("Show the agent's thinking")}</strong>
          <span>
            Asks the model to summarise its reasoning. It thinks either way; turning this off
            only stops the summary being requested.
          </span>
          <div className="actions">
            <label className="scope">
              <input
                type="checkbox"
                checked={preferences.showThinking !== false}
                onChange={(e) => onChange({ ...preferences, showThinking: e.target.checked })}
              />
              {t("Shown")}
            </label>
          </div>
        </li>
        <li>
          <strong>{t("Web search")}</strong>
          <span>
            {t("Offers the model a search tool. The tool is run by the provider, not by OpenCLI, so it does nothing for a provider that does not implement it.")}
          </span>
          <div className="actions">
            <label className="scope">
              <input
                type="checkbox"
                checked={preferences.webSearch ?? false}
                onChange={(e) => onChange({ ...preferences, webSearch: e.target.checked })}
              />
              {t("Offered")}
            </label>
          </div>
        </li>
        <li>
          <strong>{t("Research mode")}</strong>
          <span>
            {t("Adds instructions asking for evidence and sources. Instructions, not a retrieval pipeline — it is only as good as the tools the agent already has.")}
          </span>
          <div className="actions">
            <label className="scope">
              <input
                type="checkbox"
                checked={preferences.research ?? false}
                onChange={(e) => onChange({ ...preferences, research: e.target.checked })}
              />
              {t("On")}
            </label>
          </div>
        </li>
      </ul>

      <h3>{t("When to ask permission")}</h3>
      <p className="hint">
        {t("For chats started from here. The same setting lives in Settings, where it is written to your configuration file and applies to every interface.")}
      </p>
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
        <p className="error">{t("The agent will run commands on this machine without asking.")}</p>
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

const STATUS_LABEL: Record<RunStatus, () => string> = {
  queued: () => t("Queued"),
  running: () => t("Running"),
  done: () => t("Done"),
  failed: () => t("Failed"),
  cancelled: () => t("Cancelled"),
};

/** One run, expandable to show what it printed. */
function RunRow({
  run,
  onCancel,
  onDelete,
  onOpenAsChat,
}: {
  run: Run;
  onCancel: (id: string) => void;
  onDelete: (id: string) => void;
  /** Continue where the run left off, in a chat you can talk to. */
  onOpenAsChat?: (run: Run) => void;
}) {
  const finished = run.status === "done" || run.status === "failed" || run.status === "cancelled";
  // A run still going is open by default: it is being watched, and the output
  // arrives as the agent produces it.
  const [open, setOpen] = useState(!finished);
  const tail = useRef<HTMLPreElement>(null);

  // Follow the end while it is running, so the newest line is the visible one.
  useEffect(() => {
    if (open && !finished) tail.current?.scrollTo({ top: tail.current.scrollHeight });
  }, [finished, open, run.output]);

  return (
    <li className={`run ${run.status}`}>
      <div className="run-head">
        <i className={`run-dot ${run.status}`} />
        <span className="run-what">
          <strong>{run.title}</strong>
          <em>
            {STATUS_LABEL[run.status]()} · {ago(run.finishedAt ?? run.startedAt)} · {run.source}
          </em>
        </span>
        <span className="actions">
          {run.output ? (
            <button className="secondary" onClick={() => setOpen(!open)}>
              {open ? t("Hide") : t("Output")}
            </button>
          ) : null}
          {finished && onOpenAsChat ? (
            <button className="secondary" onClick={() => onOpenAsChat(run)}>
              {t("Continue in a chat")}
            </button>
          ) : null}
          {finished ? (
            <button className="secondary" onClick={() => onDelete(run.id)}>
              {t("Remove")}
            </button>
          ) : (
            <button className="secondary" onClick={() => onCancel(run.id)}>
              {t("Cancel")}
            </button>
          )}
        </span>
      </div>
      {open ? (
        <pre className={`run-output${finished ? "" : " live"}`} ref={tail}>
          {run.output || "Waiting for the agent to say something…"}
        </pre>
      ) : null}
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
export function DispatchView({
  client,
  cwd,
  model,
  onOpenAsChat,
}: {
  client: OpenCliClient;
  cwd: string;
  model: string;
  /** Pick a finished run up as a conversation. */
  onOpenAsChat?: (run: Run) => void;
}) {
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

  const active = runs.filter((run) => run.status === "queued" || run.status === "running");

  // Faster while something is running: the output arrives as the agent
  // produces it, and four seconds between glimpses of a live log is a long
  // time to watch nothing.
  useEffect(() => {
    void reload();
    const timer = setInterval(() => void reload(), active.length > 0 ? 1500 : 6000);
    return () => clearInterval(timer);
  }, [active.length, reload]);

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

  const past = runs.filter((run) => run.status !== "queued" && run.status !== "running");

  return (
    <section className="panel">
      <h2>{t("Dispatch")}</h2>
      <p className="hint">
        {t("Send work off to run on its own. Each run is a separate agent in its own directory, so it keeps going after you close the chat that started it. Three run at a time.")}
      </p>
      {error ? <p className="error">{error}</p> : null}

      <div className="project-form">
        <textarea
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          placeholder={t("What should it do?")}
          rows={3}
        />
        <span className="path-input">
          <input
            value={directory}
            onChange={(e) => setDirectory(e.target.value)}
            placeholder={t("/path/to/work/in")}
          />
        </span>
        <div className="actions">
          <button onClick={() => void dispatch()} disabled={!prompt.trim()}>
            {t("Dispatch")}
          </button>
        </div>
      </div>

      <h3>{t("Active")}</h3>
      <ul className="rows wide">
        {active.length === 0 ? <li className="muted">{t("Nothing running.")}</li> : null}
        {active.map((run) => (
          <RunRow
            key={run.id}
            run={run}
            onCancel={(id) => void client.cancelRun(id).then(reload)}
            onDelete={(id) => void client.deleteRun(id).then(reload)}
            onOpenAsChat={onOpenAsChat}
          />
        ))}
      </ul>

      <h3>
        {t("Finished")}
        {past.length > 0 ? (
          <button className="link clear" onClick={() => void client.clearRuns().then(reload)}>
            {t("Clear")}
          </button>
        ) : null}
      </h3>
      <ul className="rows wide">
        {past.length === 0 ? <li className="muted">{t("Nothing has run yet.")}</li> : null}
        {past.map((run) => (
          <RunRow
            key={run.id}
            run={run}
            onCancel={(id) => void client.cancelRun(id).then(reload)}
            onDelete={(id) => void client.deleteRun(id).then(reload)}
            onOpenAsChat={onOpenAsChat}
          />
        ))}
      </ul>
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
  onStartChat,
  onOpenThread,
  onChanged,
  onBack,
}: {
  client: OpenCliClient;
  project: Project;
  threads: ThreadSummary[];
  onNewChat: () => void;
  /** Opens a chat here with this as its first message. */
  onStartChat: (text: string) => void;
  onOpenThread: (id: string) => void;
  onChanged: () => void;
  onBack: () => void;
}) {
  const [files, setFiles] = useState<ProjectFile[]>([]);
  const [filesError, setFilesError] = useState<string | null>(null);
  const [instructions, setInstructions] = useState(project.instructions);
  const [saved, setSaved] = useState(false);
  const [prompt, setPrompt] = useState("");

  useEffect(() => {
    setInstructions(project.instructions);
    setSaved(false);
    setPrompt("");
  }, [project.id, project.instructions]);

  const start = useCallback(() => {
    const text = prompt.trim();
    if (!text) return;
    setPrompt("");
    onStartChat(text);
  }, [onStartChat, prompt]);

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
          {t("← Projects")}
        </button>
      </div>

      <div className="panel-head">
        <h2 className="display">{project.name}</h2>
        <span className="grow" />
        <button className="filled" onClick={onNewChat}>
          {t("New chat")}
        </button>
      </div>
      <p className="hint">
        {project.description || "No description."} · {project.cwd}
      </p>

      {/* A project is somewhere to work, so the way to start working is here
          rather than two clicks away in an empty chat. */}
      <div className="project-composer">
        <textarea
          value={prompt}
          rows={2}
          placeholder={t("Start a new chat in {project}…", { project: project.name })}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyDown={(e) => {
            if (shouldSend({ ...e, isComposing: e.nativeEvent.isComposing })) {
              e.preventDefault();
              start();
            }
          }}
        />
        <button className="filled" disabled={prompt.trim() === ""} onClick={start}>
          <SendIcon size={15} />
        </button>
      </div>

      <h3>{t("Chats")}</h3>
      <ul className="rows">
        {own.length === 0 ? (
          <li className="muted">{t("No chats here yet. Start one and it will be grouped here.")}</li>
        ) : null}
        {own.map((thread) => (
          <li key={thread.id}>
            <strong>{thread.name ?? thread.preview}</strong>
            <span>{ago(thread.updatedAt)}</span>
            <div className="actions">
              <button className="secondary" onClick={() => onOpenThread(thread.id)}>
                {t("Open")}
              </button>
            </div>
          </li>
        ))}
      </ul>

      <h3>{t("In this folder")}</h3>
      {filesError ? <p className="error">{filesError}</p> : null}
      <ul className="rows files">
        {!filesError && files.length === 0 ? <li className="muted">{t("Empty.")}</li> : null}
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

      <h3>{t("Standing instructions")}</h3>
      <p className="hint">
        {t("Given to the agent in every chat opened here. Changes apply to the next chat, not the one already open.")}
      </p>
      <div className="project-form">
        <textarea
          value={instructions}
          onChange={(e) => {
            setInstructions(e.target.value);
            setSaved(false);
          }}
          rows={5}
          placeholder={t("How to build it, what not to touch…")}
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
            {t("Save")}
          </button>
          {saved ? <span className="field-note">{t("Saved.")}</span> : null}
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
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  /**
   * What changed in the configuration, and so what a new chat would pick up.
   *
   * The agent reads its settings once, when a chat opens. Adding a model and
   * removing one both leave an open chat out of date, and removal is the worse
   * of the two: the picker keeps offering something that is no longer there.
   */
  const [configNote, setConfigNote] = useState<string | null>(null);
  const [managing, setManaging] = useState(false);
  const [discovered, setDiscovered] = useState<DiscoveredRuntime[]>([]);

  const [query, setQuery] = useState("");
  const [popular, setPopular] = useState<Offer[]>([]);
  const [popularTotal, setPopularTotal] = useState(0);
  const [popularStale, setPopularStale] = useState(false);
  const [found, setFound] = useState<Offer[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [installing, setInstalling] = useState<Offer | null>(null);
  const [targets, setTargets] = useState<InstallTarget[]>([]);
  const [targetsLoading, setTargetsLoading] = useState(true);
  /**
   * What is happening to a given row, keyed by machine and model.
   *
   * Registering takes a moment and removing takes seconds against a remote
   * machine. Without this the buttons sat silent for that whole time and read
   * as dead — which is what they were reported as.
   */
  const [working, setWorking] = useState<Record<string, string>>({});
  const [said, setSaid] = useState<Record<string, string>>({});
  /** Model names the chat picker already offers, per machine. */
  const [inPicker, setInPicker] = useState<Record<string, string[]>>({});

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const [rows, here] = await Promise.all([
        // Shown as they arrive: a machine on this computer answers in
        // milliseconds while one across the internet takes seconds, and each
        // model's capabilities cost a round trip of their own.
        client.allInstalledModels((partial) => {
          setInstalled(partial);
          setLoading(false);
        }),
        client.discoverRuntimes().catch(() => []),
      ]);
      setInstalled(rows);
      setDiscovered(here);
      setError(null);

      // Which of these the chat picker offers. Asked per machine because the
      // provider a model belongs to is derived from its address.
      const machines = [...new Set(rows.map((row) => row.baseUrl))];
      void Promise.all(
        machines.map(async (baseUrl) => [
          baseUrl,
          await client.registeredModels(baseUrl).catch(() => [] as string[]),
        ]),
      ).then((pairs) => setInPicker(Object.fromEntries(pairs as [string, string[]][])));
      // Gathered while the user browses rather than when Install is pressed,
      // so the dialog opens on data already in hand instead of on a round trip
      // to every machine. Refreshed here too, so "already installed there"
      // stays true after an install or a removal.
      setTargetsLoading(true);
      void client
        .installTargets()
        .then(setTargets)
        .catch(() => setTargets([]))
        .finally(() => setTargetsLoading(false));
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    void reload();
    void client.modelCatalog().then(setLibrary).catch(() => setLibrary([]));
    // Fetched when the panel mounts, not when Browse is opened: it comes from
    // a cache the gateway warms at startup, so by the time anyone switches
    // tabs there is a list waiting rather than a spinner.
    void client
      .popularModels({ limit: 20 })
      .then((result) => {
        setPopular(result.models);
        setPopularTotal(result.total);
        setPopularStale(result.stale);
      })
      .catch(() => setPopular([]));
  }, [client, reload]);

  const showMore = useCallback(() => {
    void client
      .popularModels({ offset: popular.length, limit: 20 })
      .then((result) => setPopular((prev) => [...prev, ...result.models]))
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [client, popular.length]);

  // Typing narrows what is already on screen, and reaches Hugging Face for
  // what is not. It refines a populated page rather than being the way in:
  // needing a name to see anything is what made the panel useless to someone
  // who does not know one.
  useEffect(() => {
    const term = query.trim();
    if (!term || term.includes("/") || term.includes(":")) {
      setFound(null);
      return;
    }
    setSearching(true);
    const timer = setTimeout(() => {
      void client
        .searchModels(term, "huggingface")
        .then((result) => setFound(result.results))
        .catch(() => setFound([]))
        .finally(() => setSearching(false));
    }, 400);
    return () => {
      clearTimeout(timer);
      setSearching(false);
    };
  }, [client, query]);

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
      if (registered > 0) {
        setConfigNote(
          "Installed and added to your configuration. Start a new chat to use it — the agent reads its settings when a chat opens.",
        );
      }
      // Back to what you now own, which is where a finished install belongs.
      setTab("installed");
      await reload();
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [finished]);

  const inFlight = Object.values(pulls).filter((pull) => !pull.done && !pull.error);

  const term = query.trim().toLowerCase();
  // The curated entries are filtered here rather than re-fetched: twelve rows
  // already in hand need no round trip to narrow.
  const shortlist = term
    ? library.filter(
        (offer) =>
          offer.name.toLowerCase().includes(term) || offer.tag.toLowerCase().includes(term),
      )
    : library;
  const fromHub = found ?? popular;

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
        <h2 className="display">{t("Models")}</h2>
        <span className="grow" />
        <button className="secondary" onClick={() => setManaging(true)}>
          {t("Machines…")}
        </button>
      </div>

      <div className="tabs">
        <button className={tab === "installed" ? "on" : ""} onClick={() => setTab("installed")}>
          Installed{installed.length > 0 ? ` (${installed.length})` : ""}
        </button>
        <button className={tab === "browse" ? "on" : ""} onClick={() => setTab("browse")}>
          {t("Browse")}
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {configNote ? <p className="notice">{configNote}</p> : null}

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
          {loading ? <p className="muted">{t("Looking on every machine…")}</p> : null}
          {!loading && installed.length === 0 ? (
            <p className="muted">
              {t("Nothing installed anywhere yet. Open Browse to add one.")}
            </p>
          ) : null}
          <ul className="rows">
            {installed.map((row) => {
              const key = `${row.baseUrl}:${row.model.name}`;
              const busy = working[key];
              const usable = (inPicker[row.baseUrl] ?? []).includes(row.model.name);
              return (
              <li key={key}>
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
                      ? t("Calls tools")
                      : t("Does not call tools — of little use for agent work here")}
                  </span>
                ) : (
                  <span className="muted-note">{t("Checking what it can do…")}</span>
                )}
                {said[key] ? (
                  <span className="done">{said[key]}</span>
                ) : usable ? (
                  <span className="done">{t("In the chat model picker")}</span>
                ) : (
                  <span className="muted-note">
                    {t("Not in the chat picker yet — installed here, but chats cannot select it.")}
                  </span>
                )}
                <div className="actions">
                  <button
                    className="secondary"
                    title={t("Add it to the model picker")}
                    disabled={!!busy || usable}
                    onClick={() => {
                      setWorking((prev) => ({ ...prev, [key]: "adding" }));
                      void client
                        .registerModel(row.baseUrl, row.model.name)
                        .then((result) => {
                          setError(null);
                          if (result.added) {
                            setConfigNote(
                              "Added to your configuration. Start a new chat to use it — the agent reads its settings when a chat opens.",
                            );
                          }
                          // Said here rather than only at the top of the panel:
                          // with several models on screen the notice up there
                          // is off-screen, so the click looked ignored.
                          setSaid((prev) => ({
                            ...prev,
                            [key]: result.added
                              ? t("Added to the picker — start a new chat to use it.")
                              : t("Already in the picker."),
                          }));
                          setInPicker((prev) => ({
                            ...prev,
                            [row.baseUrl]: [...(prev[row.baseUrl] ?? []), row.model.name],
                          }));
                        })
                        .catch((err: unknown) =>
                          setError(err instanceof Error ? err.message : String(err)),
                        )
                        .finally(() =>
                          setWorking((prev) => {
                            const next = { ...prev };
                            delete next[key];
                            return next;
                          }),
                        );
                    }}
                  >
                    {busy === "adding" ? "Adding…" : usable ? "Already usable" : "Use in chats"}
                  </button>
                  <button
                    className="secondary"
                    disabled={!!busy}
                    onClick={() => {
                      setWorking((prev) => ({ ...prev, [key]: "removing" }));
                      void client
                        .deleteModel(row.baseUrl, row.model.name)
                        .then(() => {
                          // Dropped here rather than waiting on a fresh look at
                          // every machine, which takes seconds. The reload runs
                          // behind it to catch anything else that changed.
                          setInstalled((prev) =>
                            prev.filter(
                              (other) =>
                                other.baseUrl !== row.baseUrl ||
                                other.model.name !== row.model.name,
                            ),
                          );
                          setConfigNote(
                            "Removed. A chat that is already open will keep offering it until you start a new one — the agent reads its settings when a chat opens.",
                          );
                          void reload();
                        })
                        .catch((err: unknown) => {
                          setError(err instanceof Error ? err.message : String(err));
                          setWorking((prev) => {
                            const next = { ...prev };
                            delete next[key];
                            return next;
                          });
                        });
                    }}
                  >
                    {busy === "removing" ? "Removing…" : "Remove"}
                  </button>
                </div>
              </li>
              );
            })}
          </ul>
        </>
      ) : (
        <>
          <div className="task-form">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => {
                if (shouldDismiss({ ...e, isComposing: e.nativeEvent.isComposing })) setQuery("");
              }}
              placeholder={t("Narrow the list, or paste a tag like hf.co/owner/repo")}
            />
            {query ? (
              <button className="secondary" onClick={() => setQuery("")}>
                {t("Clear")}
              </button>
            ) : null}
          </div>
          <p className="hint">
            Anything installable can also be pasted straight in — an Ollama tag, an{" "}
            <code>{t("hf.co/owner/repo")}</code>
            {t(", or a")} <code>{t("modelscope.cn/owner/repo")}</code>.
          </p>

          {typedTag ? (
            <ul className="rows">
              <li>
                <strong>{typedTag}</strong>
                <span>{t("Install this exactly as typed.")}</span>
                <div className="actions">
                  <button
                    onClick={() =>
                      setInstalling({ source: "ollama", tag: typedTag, name: typedTag, tools: null })
                    }
                  >
                    {t("Install")}
                  </button>
                </div>
              </li>
            </ul>
          ) : null}

          {shortlist.length > 0 ? (
            <>
              <h3>Recommended · {shortlist.length}</h3>
              <PurposeGroups
                offers={shortlist}
                whereInstalled={whereInstalled}
                onInstall={setInstalling}
              />
            </>
          ) : null}

          <h3>
            {found ? t("On Hugging Face") : t("Popular on Hugging Face")}
            {searching ? " · searching…" : fromHub.length > 0 ? ` · ${fromHub.length}` : ""}
          </h3>
          {!found && popularStale ? (
            <p className="hint">{t("These rankings are from an earlier session, and are refreshing.")}</p>
          ) : null}
          <ul className="rows">
            {fromHub.length === 0 && !searching ? (
              <li className="muted">
                {found
                  ? t("Nothing on Hugging Face matched that.")
                  : t("The list of popular models could not be fetched. Anything above still installs.")}
              </li>
            ) : null}
            {fromHub.map((offer) => (
              <OfferRow
                key={offer.tag}
                offer={offer}
                where={whereInstalled.get(offer.tag) ?? []}
                onInstall={() => setInstalling(offer)}
              />
            ))}
          </ul>
          {!found && popular.length > 0 && popular.length < popularTotal ? (
            <button className="secondary" onClick={showMore}>
              {t("Show more")}
            </button>
          ) : null}
        </>
      )}

      <InstallDialog
        client={client}
        offer={installing}
        targets={targets}
        targetsLoading={targetsLoading}
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
        <span>{t("Whether it calls tools is only known once installed.")}</span>
      ) : null}
      {where.length > 0 ? (
        <span className="chip-plain">Already on {where.join(", ")}</span>
      ) : null}
      <div className="actions">
        <button onClick={onInstall}>
          {where.length > 0 ? t("Install elsewhere") : t("Install")}
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
    { id: "coding", label: t("Coding") },
    { id: "general", label: t("General purpose") },
    { id: "small", label: t("Small and fast") },
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
  targets,
  targetsLoading,
  onClose,
  onInstall,
}: {
  client: OpenCliClient;
  offer: Offer | null;
  /** Loaded by the panel while browsing, so this opens without a round trip. */
  targets: InstallTarget[];
  /** Still being gathered, which is a different thing from none existing. */
  targetsLoading: boolean;
  onClose: () => void;
  onInstall: (baseUrl: string, tag: string) => void;
}) {
  const [chosen, setChosen] = useState<string>("");
  /** Memory per machine, filled in as each is looked at. */
  const [memory, setMemory] = useState<Record<string, number | null>>({});
  const [reading, setReading] = useState(false);
  const [variants, setVariants] = useState<ModelVariant[]>([]);
  const [variant, setVariant] = useState<string>("");
  const [showVariants, setShowVariants] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const needsVariant = offer?.source === "huggingface" && offer.needsQuant;

  useEffect(() => {
    if (!offer) return;
    setError(null);
    setShowVariants(false);
    // Prefer somewhere it can actually go, and somewhere it is not already.
    const usable = targets.find((row) => row.reachable && !row.installed.includes(offer.tag));
    setChosen(usable?.baseUrl ?? targets.find((row) => row.reachable)?.baseUrl ?? "");
  }, [offer, targets]);

  // Memory is read for the chosen machine only, and after the dialog is
  // already usable. Reading every machine up front is what made opening it
  // wait on an SSH round trip per server.
  useEffect(() => {
    if (!chosen || chosen in memory) return;
    setReading(true);
    void client
      .machineMemoryGb(chosen)
      .then((gb) => setMemory((prev) => ({ ...prev, [chosen]: gb })))
      .catch(() => setMemory((prev) => ({ ...prev, [chosen]: null })))
      .finally(() => setReading(false));
  }, [client, chosen, memory]);

  // The recommendation follows the machine, so it is worked out again whenever
  // the machine or its memory changes rather than chosen once.
  const chosenMemory = memory[chosen] ?? null;
  useEffect(() => {
    if (!offer || !needsVariant || !chosen || reading) return;
    void client
      .modelVariants(offer.tag, chosenMemory ?? undefined)
      .then((result) => {
        setVariants(result.variants);
        setVariant(result.recommended ?? result.variants[0]?.tag ?? "");
      })
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [client, offer, needsVariant, chosen, chosenMemory, reading]);

  if (!offer) return null;

  const target = targets.find((row) => row.baseUrl === chosen);
  const tag = needsVariant ? variant : offer.tag;
  const already = target?.installed.includes(tag) ?? false;
  const chosenVariant = variants.find((row) => row.tag === variant);
  const known = chosen in memory;
  const fits =
    chosenMemory == null
      ? null
      : needsVariant
        ? (chosenVariant?.fits ?? null)
        : offer.needsGb
          ? offer.needsGb <= chosenMemory
          : null;

  return (
    <Dialog
      open
      title={`Install ${offer.name}`}
      onClose={onClose}
      footer={
        <>
          <button className="secondary" onClick={onClose}>
            {t("Cancel")}
          </button>
          <button
            className="filled"
            disabled={!chosen || !tag || already || targetsLoading}
            onClick={() => onInstall(chosen, tag)}
          >
            {targetsLoading ? t("Looking…") : already ? t("Already there") : t("Install")}
          </button>
        </>
      }
    >
      {error ? <p className="error">{error}</p> : null}

      <label className="field">
        Which machine?
        {targets.length === 0 ? (
          <span className="field-note">
            {targetsLoading
              ? t("Looking for machines…")
              : t("No machine found. Open Machines… to add one, or install Ollama on this computer.")}
          </span>
        ) : null}
        <select value={chosen} onChange={(e) => setChosen(e.target.value)}>
          {targets.map((row) => (
            <option key={row.baseUrl} value={row.baseUrl} disabled={!row.reachable}>
              {row.label}
              {row.reachable ? "" : " — not answering"}
              {memory[row.baseUrl] ? ` · ${memory[row.baseUrl]} GB` : ""}
            </option>
          ))}
        </select>
        {target && fits === false ? (
          <span className="field-note warn">
            {t("This is larger than the memory on that machine. It will download, and may fail to load.")}
          </span>
        ) : null}
        {reading ? (
          <span className="field-note">{t("Checking how much memory it has…")}</span>
        ) : null}
        {target && known && chosenMemory == null ? (
          <span className="field-note">
            {t("How much memory that machine has cannot be read from here, so whether it fits is not known. Adding an SSH alias in Machines… would let it be checked.")}
          </span>
        ) : null}
        {already ? (
          <span className="field-note">{t("It is already installed there.")}</span>
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
                {showVariants ? t("Keep this one") : t("Choose a different one")}
              </button>
            </div>
          ) : (
            <span className="field-note">{t("Reading the available versions…")}</span>
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
    <Dialog open={open} title={t("Machines")} onClose={onClose}>
      {error ? <p className="error">{error}</p> : null}

      {unsaved.length > 0 ? (
        <>
          <h3>{t("Found on this machine")}</h3>
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
                    {t("Save it")}
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </>
      ) : null}

      <h3>{t("Saved")}</h3>
      <ul className="rows">
        {servers.length === 0 ? <li className="muted">{t("None saved.")}</li> : null}
        {servers.map((server) => {
          const report = reports[server.id];
          return (
            <li key={server.id}>
              <strong>{server.name}</strong>
              <span>{server.baseUrl}</span>
              <span>
                {server.sshAlias
                  ? t("SSH: {alias} — can be inspected and repaired", { alias: server.sshAlias })
                  : t("No SSH — models only")}
              </span>

              {report ? (
                <div className="report">
                  {report.shell ? (
                    <dl>
                      <dt>{t("Runtime")}</dt>
                      <dd>
                        {report.http.reachable
                          ? `answering, ${report.http.version}`
                          : "not answering"}
                      </dd>
                      <dt>{t("Service")}</dt>
                      <dd>
                        {report.shell.service || "none"}
                        {report.shell.restarts > 0 ? ` · ${report.shell.restarts} restarts` : ""}
                      </dd>
                      <dt>{t("Models on disk")}</dt>
                      <dd>{report.shell.modelsOnDisk || "unknown"}</dd>
                      <dt>{t("Disk free")}</dt>
                      <dd>{report.shell.diskFree || "unknown"}</dd>
                      {report.shell.gpu ? (
                        <>
                          <dt>{t("GPU")}</dt>
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
                  {t("Remove")}
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
              placeholder={t("GPU Box")}
            />
          </label>
          <label className="field">
            Where does the runtime answer?
            <input
              value={draft.baseUrl}
              onChange={(e) => setDraft({ ...draft, baseUrl: e.target.value })}
              placeholder={t("https://llm.example.com or http://192.168.1.20:11434")}
            />
          </label>
          <label className="field">
            Can it also be reached by SSH? (optional)
            <select
              value={draft.sshAlias}
              onChange={(e) => setDraft({ ...draft, sshAlias: e.target.value })}
            >
              <option value="">{t("No — manage models only")}</option>
              {aliases.map((host) => (
                <option key={host.alias} value={host.alias}>
                  {host.alias} — {host.user ? `${host.user}@` : ""}
                  {host.hostname}:{host.port}
                </option>
              ))}
            </select>
            <span className="field-note">
              {aliases.length === 0
                ? t("No hosts in ~/.ssh/config. Add one there and it will appear here.")
                : t("Read from your own ~/.ssh/config. No key or password is stored.")}
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
              {t("Add")}
            </button>
            <button className="secondary" onClick={() => setAdding(false)}>
              {t("Cancel")}
            </button>
          </div>
        </div>
      ) : (
        <button className="secondary" onClick={() => setAdding(true)}>
          {t("Add a server elsewhere…")}
        </button>
      )}
    </Dialog>
  );
}
