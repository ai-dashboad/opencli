import { useMemo, useState } from "react";
import type { Project, ScheduledTask, ThreadSummary } from "./protocol";
import {
  ArtifactIcon,
  ChevronIcon,
  ClockIcon,
  ConnectorIcon,
  MemoryIcon,
  PaletteIcon,
  PlusIcon,
  ProjectIcon,
  SearchIcon,
  SettingsIcon,
  SkillIcon,
  SlidersIcon,
} from "./icons";

export type View =
  | "chat"
  | "projects"
  | "artifacts"
  | "memory"
  | "customize"
  | "scheduled"
  | "skills"
  | "connectors"
  | "settings";

interface SidebarProps {
  view: View;
  threads: ThreadSummary[];
  projects: Project[];
  tasks: ScheduledTask[];
  activeThreadId: string | null;
  activeProjectId: string | null;
  onNavigate: (view: View) => void;
  onNewChat: () => void;
  onOpenThread: (id: string) => void;
  onOpenProject: (project: Project) => void;
  onRenameThread: (id: string, name: string) => void;
  onArchiveThread: (id: string) => void;
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
  { id: "memory", label: "Memory", icon: <MemoryIcon /> },
  { id: "customize", label: "Customize", icon: <SlidersIcon /> },
];

const SECONDARY: { id: View; label: string; icon: React.ReactNode }[] = [
  { id: "skills", label: "Skills", icon: <SkillIcon /> },
  { id: "connectors", label: "Connectors", icon: <ConnectorIcon /> },
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
  activeProjectId,
  onNavigate,
  onNewChat,
  onOpenThread,
  onOpenProject,
  onRenameThread,
  onArchiveThread,
}: SidebarProps) {
  const [query, setQuery] = useState("");
  const [searching, setSearching] = useState(false);

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
              {active.map((task) => (
                <li key={task.id}>
                  <button className="tree-row" onClick={() => onNavigate("scheduled")}>
                    <i className="dot" />
                    <span>{task.name}</span>
                  </button>
                </li>
              ))}
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
                    className={`tree-row folder${
                      project.id === activeProjectId ? " active" : ""
                    }`}
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
                            <i className={`dot${thread.id === activeThreadId ? " on" : ""}`} />
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
                if (event.key === "Escape") {
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
                    <i className={`dot${thread.id === activeThreadId ? " on" : ""}`} />
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
            <PaletteIcon size={14} />
          </span>
          <span className="who">OpenCLI</span>
          <ChevronIcon size={14} />
        </div>
      </div>
    </nav>
  );
}
