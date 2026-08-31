import type { ThreadSummary } from "./protocol";

export type View = "chat" | "scheduled" | "skills" | "connectors" | "settings";

interface SidebarProps {
  view: View;
  threads: ThreadSummary[];
  activeThreadId: string | null;
  onNavigate: (view: View) => void;
  onNewChat: () => void;
  onOpenThread: (id: string) => void;
}

/** Trim a preview to one readable line for the list. */
function summarize(thread: ThreadSummary): string {
  const text = (thread.name ?? thread.preview).replace(/\s+/g, " ").trim();
  return text.length > 44 ? `${text.slice(0, 44)}…` : text || "(empty)";
}

/** Coarse relative time; the list only needs recency, not precision. */
function ago(seconds: number): string {
  if (!seconds) return "";
  const delta = Date.now() / 1000 - seconds;
  if (delta < 3600) return `${Math.max(1, Math.floor(delta / 60))}m`;
  if (delta < 86400) return `${Math.floor(delta / 3600)}h`;
  return `${Math.floor(delta / 86400)}d`;
}

export default function Sidebar({
  view,
  threads,
  activeThreadId,
  onNavigate,
  onNewChat,
  onOpenThread,
}: SidebarProps) {
  const items: { id: View; label: string }[] = [
    { id: "scheduled", label: "Scheduled" },
    { id: "skills", label: "Skills" },
    { id: "connectors", label: "Connectors" },
    { id: "settings", label: "Settings" },
  ];

  return (
    <nav className="sidebar">
      <button className="new" onClick={onNewChat}>
        + New chat
      </button>

      <ul className="nav">
        {items.map((item) => (
          <li key={item.id}>
            <button
              className={view === item.id ? "active" : ""}
              onClick={() => onNavigate(item.id)}
            >
              {item.label}
            </button>
          </li>
        ))}
      </ul>

      <div className="section-label">Chats</div>
      <ul className="threads">
        {threads.length === 0 ? (
          <li className="empty">No saved chats yet</li>
        ) : (
          threads.map((thread) => (
            <li key={thread.id}>
              <button
                className={thread.id === activeThreadId ? "active" : ""}
                onClick={() => onOpenThread(thread.id)}
                title={thread.preview}
              >
                <span className="preview">{summarize(thread)}</span>
                <span className="when">{ago(thread.updatedAt)}</span>
              </button>
            </li>
          ))
        )}
      </ul>
    </nav>
  );
}
