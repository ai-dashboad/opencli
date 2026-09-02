import { useMemo, useState } from "react";
import { shouldDismiss } from "./composer";
import type { Project, ScheduledTask, ThreadSummary } from "./protocol";
import {
  ArrowLeftIcon,
  ArrowRightIcon,
  ArtifactIcon,
  DispatchIcon,
  ChevronIcon,
  ClockIcon,
  ConnectorIcon,
  MemoryIcon,
  OpenCliMark,
  ChipIcon,
  PlugIcon,
  PlusIcon,
  ProjectIcon,
  SearchIcon,
  SettingsIcon,
  SidebarToggleIcon,
  SkillIcon,
  SlidersIcon,
  WorkingDot,
} from "./icons";

export type View =
  | "chat"
  | "projects"
  | "artifacts"
  | "memory"
  | "customize"
  | "dispatch"
  | "scheduled"
  | "skills"
  | "connectors"
  | "plugins"
  | "models"
  | "project"
  | "settings";

interface SidebarProps {
  view: View;
  threads: ThreadSummary[];
  projects: Project[];
  tasks: ScheduledTask[];
  activeThreadId: string | null;
  /** The chat the agent is working in, when it is working in one. */
  runningThreadId: string | null;
  /** The project holding the open chat: marked, but not the selected row. */
  activeProjectId: string | null;
  /** The project whose own page is on screen, which is a selection. */
  viewedProjectId: string | null;
  onNavigate: (view: View) => void;
  onNewChat: () => void;
  onOpenThread: (id: string) => void;
  onOpenProject: (project: Project) => void;
  onRenameThread: (id: string, name: string) => void;
  onArchiveThread: (id: string) => void;
  onToggle: () => void;
  onBack: () => void;
  onForward: () => void;
  canBack: boolean;
  canForward: boolean;
}

/**
 * The marker in front of a chat in the list.
 *
 * A chat that is working shows the same beating mark as the transcript does,
 * so a run that was started and then navigated away from is visible from
 * anywhere — before this, the list gave no sign which chat was busy, and the
 * only way to find out was to open each one.
 */
function ThreadDot({ running, active }: { running: boolean; active: boolean }) {
  if (running) return <WorkingDot size={10} />;
  return <i className={`dot${active ? " on" : ""}`} />;
}

const SEEN_KEY = "opencli.scheduled.seen";

/**
 * Runs the user has already looked at, per task.
 *
 * Stored locally rather than on the server: "have I read this" belongs to the
 * person at this machine, not to the task, and two windows disagreeing about
 * it is harmless.
 */
function readSeen(): Record<string, number> {
  try {
    const raw = window.localStorage.getItem(SEEN_KEY);
    return raw ? (JSON.parse(raw) as Record<string, number>) : {};
  } catch {
    return {};
  }
}

function writeSeen(seen: Record<string, number>): void {
  try {
    window.localStorage.setItem(SEEN_KEY, JSON.stringify(seen));
  } catch {
    // A full or disabled store only costs the unread badges.
  }
}

/** One readable line for a chat row. */
function summarize(thread: ThreadSummary): string {
  const text = (thread.name ?? thread.preview).replace(/\s+/g, " ").trim();
  return text || "New chat";
}

const NAV: { id: View; label: string; icon: React.ReactNode; badge?: string }[] = [
  { id: "projects", label: "Projects", icon: <ProjectIcon /> },
  { id: "artifacts", label: "Artifacts", icon: <ArtifactIcon /> },
  { id: "scheduled", label: "Scheduled", icon: <ClockIcon /> },
  { id: "dispatch", label: "Dispatch", icon: <DispatchIcon />, badge: "Beta" },
  { id: "memory", label: "Memory", icon: <MemoryIcon /> },
  { id: "customize", label: "Customize", icon: <SlidersIcon /> },
];

const SECONDARY: { id: View; label: string; icon: React.ReactNode }[] = [
  { id: "skills", label: "Skills", icon: <SkillIcon /> },
  { id: "connectors", label: "Connectors", icon: <ConnectorIcon /> },
  { id: "plugins", label: "Plugins", icon: <PlugIcon /> },
  { id: "models", label: "Models", icon: <ChipIcon /> },
  { id: "settings", label: "Settings", icon: <SettingsIcon /> },
];

/** A collapsible group with a label and an optional action on the right. */
function Section({
  label,
  action,
  children,
}: {
  label: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <div className="group">
      <div className="group-head">
        <span>{label}</span>
        {action ? <span className="group-actions">{action}</span> : null}
      </div>
      {children}
    </div>
  );
}

export default function Sidebar({
  view,
  threads,
  projects,
  tasks,
  activeThreadId,
  runningThreadId,
  activeProjectId,
  viewedProjectId,
  onNavigate,
  onNewChat,
  onOpenThread,
  onOpenProject,
  onRenameThread,
  onArchiveThread,
  onToggle,
  onBack,
  onForward,
  canBack,
  canForward,
}: SidebarProps) {
  const [query, setQuery] = useState("");
  const [searching, setSearching] = useState(false);
  const [seen, setSeen] = useState<Record<string, number>>(readSeen);

  // Chats already shown under a project are not repeated in the flat list;
  // seeing the same conversation twice makes the tree look untrustworthy.
  const grouped = useMemo(
    () => new Set(projects.flatMap((project) => project.threadIds)),
    [projects],
  );
  const byId = useMemo(() => new Map(threads.map((thread) => [thread.id, thread])), [threads]);

  const loose = useMemo(() => {
    const rest = threads.filter((thread) => !grouped.has(thread.id));
    const needle = query.trim().toLowerCase();
    if (!needle) return rest;
    return rest.filter((thread) => summarize(thread).toLowerCase().includes(needle));
  }, [grouped, query, threads]);

  const active = tasks.filter((task) => task.enabled);

  return (
    <nav className="sidebar">
      {/* The window's traffic lights float over the left of this strip, so it
          is padded to clear them and made draggable to replace the title bar
          it stands in for. */}
      <div className="titlebar" data-tauri-drag-region>
        <button className="icon-button sm" title="Hide sidebar" onClick={onToggle}>
          <SidebarToggleIcon size={15} />
        </button>
        <button
          className="icon-button sm"
          title="Back"
          onClick={onBack}
          disabled={!canBack}
        >
          <ArrowLeftIcon size={15} />
        </button>
        <button
          className="icon-button sm"
          title="Forward"
          onClick={onForward}
          disabled={!canForward}
        >
          <ArrowRightIcon size={15} />
        </button>
      </div>

      <div className="sidebar-scroll">
        <button className="nav-row primary" onClick={onNewChat}>
          <PlusIcon />
          <span>New</span>
        </button>

        {NAV.map((item) => (
          <button
            key={item.id}
            className={`nav-row${view === item.id ? " active" : ""}`}
            onClick={() => onNavigate(item.id)}
          >
            {item.icon}
            <span>{item.label}</span>
            {item.badge ? <em className="pill">{item.badge}</em> : null}
          </button>
        ))}

        {active.length > 0 ? (
          <Section label="Scheduled">
            <ul className="tree">
              {active.map((task) => {
                const fresh = Math.max(0, task.runCount - (seen[task.id] ?? 0));
                return (
                  <li key={task.id}>
                    <button
                      className="tree-row"
                      onClick={() => {
                        // Opening the panel is what "seeing" a run means.
                        const next = { ...seen, [task.id]: task.runCount };
                        setSeen(next);
                        writeSeen(next);
                        onNavigate("scheduled");
                      }}
                    >
                      <i className={`dot${fresh > 0 ? " on" : ""}`} />
                      <span>{task.name}</span>
                      {fresh > 0 ? <em className="pill">{fresh} new</em> : null}
                    </button>
                  </li>
                );
              })}
            </ul>
          </Section>
        ) : null}

        <Section
          label="Projects"
          action={
            <button aria-label="New project" onClick={() => onNavigate("projects")}>
              <PlusIcon size={14} />
            </button>
          }
        >
          <ul className="tree">
            {projects.length === 0 ? (
              <li className="empty">No projects yet</li>
            ) : (
              projects.map((project) => (
                <li key={project.id}>
                  <button
                    // Two different things, so two different marks: the pill
                    // means "this is what you are looking at", and belongs to
                    // one row at a time. A project whose chat is open is only
                    // shown as holding it — otherwise the chat and its project
                    // both wore the pill and neither read as the selection.
                    className={`tree-row folder${
                      project.id === viewedProjectId ? " active" : ""
                    }${project.id === activeProjectId ? " holding" : ""}`}
                    onClick={() => onOpenProject(project)}
                    title={project.cwd}
                  >
                    <ProjectIcon size={14} />
                    <span>{project.name}</span>
                  </button>
                  <ul className="tree nested">
                    {project.threadIds
                      .map((id) => byId.get(id))
                      .filter((thread): thread is ThreadSummary => thread !== undefined)
                      .map((thread) => (
                        <li key={thread.id}>
                          <button
                            className={`tree-row${
                              thread.id === activeThreadId ? " active" : ""
                            }`}
                            onClick={() => onOpenThread(thread.id)}
                            title={thread.preview}
                          >
                            <ThreadDot
                              running={thread.id === runningThreadId}
                              active={thread.id === activeThreadId}
                            />
                            <span>{summarize(thread)}</span>
                          </button>
                        </li>
                      ))}
                  </ul>
                </li>
              ))
            )}
          </ul>
        </Section>

        <Section
          label="Chats and tasks"
          action={
            <button
              aria-label="Search chats"
              className={searching ? "on" : ""}
              onClick={() => {
                setSearching(!searching);
                if (searching) setQuery("");
              }}
            >
              <SearchIcon size={14} />
            </button>
          }
        >
          {searching ? (
            <input
              className="tree-search"
              value={query}
              autoFocus
              placeholder="Filter chats"
              onChange={(event) => setQuery(event.target.value)}
              onKeyDown={(event) => {
                if (shouldDismiss({ ...event, isComposing: event.nativeEvent.isComposing })) {
                  setSearching(false);
                  setQuery("");
                }
              }}
            />
          ) : null}
          <ul className="tree">
            {loose.length === 0 ? (
              <li className="empty">{query ? "Nothing matches" : "No chats yet"}</li>
            ) : (
              loose.map((thread) => (
                <li key={thread.id} className="tree-item">
                  <button
                    className={`tree-row${thread.id === activeThreadId ? " active" : ""}`}
                    onClick={() => onOpenThread(thread.id)}
                    title={thread.preview}
                  >
                    <ThreadDot
                      running={thread.id === runningThreadId}
                      active={thread.id === activeThreadId}
                    />
                    <span>{summarize(thread)}</span>
                  </button>
                  <span className="row-actions">
                    <button
                      aria-label={`Rename ${summarize(thread)}`}
                      title="Rename"
                      onClick={() => {
                        const name = window.prompt("Name this chat", thread.name ?? "");
                        if (name?.trim()) onRenameThread(thread.id, name.trim());
                      }}
                    >
                      ✎
                    </button>
                    <button
                      aria-label={`Archive ${summarize(thread)}`}
                      title="Archive"
                      onClick={() => onArchiveThread(thread.id)}
                    >
                      ×
                    </button>
                  </span>
                </li>
              ))
            )}
          </ul>
        </Section>
      </div>

      <div className="sidebar-foot">
        {SECONDARY.map((item) => (
          <button
            key={item.id}
            className={`nav-row${view === item.id ? " active" : ""}`}
            onClick={() => onNavigate(item.id)}
          >
            {item.icon}
            <span>{item.label}</span>
          </button>
        ))}
        <div className="account">
          <span className="avatar">
            <OpenCliMark size={13} />
          </span>
          <span className="who">OpenCLI</span>
          <ChevronIcon size={14} />
        </div>
      </div>
    </nav>
  );
}
