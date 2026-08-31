import { useEffect, useRef, useState } from "react";
import type { ConnectorSummary, ModelOption, Project, ReasoningEffort, SkillSummary } from "./protocol";
import { CheckIcon, ChevronRightIcon, PaperclipIcon, ProjectIcon, SkillIcon, ConnectorIcon } from "./icons";

/**
 * A popover anchored to its trigger.
 *
 * Closes on an outside click or Escape. Both matter: a menu that can only be
 * dismissed by picking something forces a choice the user may not want to make.
 */
export function Popover({
  open,
  onClose,
  align = "left",
  children,
}: {
  open: boolean;
  onClose: () => void;
  align?: "left" | "right";
  children: React.ReactNode;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) onClose();
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    // Deferred so the click that opened the menu does not immediately close it.
    const timer = setTimeout(() => document.addEventListener("mousedown", onDown), 0);
    document.addEventListener("keydown", onKey);
    return () => {
      clearTimeout(timer);
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className={`popover ${align}`} ref={ref} role="menu">
      {children}
    </div>
  );
}

/** A row in a popover. */
export function MenuItem({
  icon,
  label,
  hint,
  shortcut,
  checked,
  submenu,
  onClick,
}: {
  icon?: React.ReactNode;
  label: string;
  hint?: string;
  shortcut?: string;
  checked?: boolean;
  submenu?: React.ReactNode;
  onClick?: () => void;
}) {
  const [open, setOpen] = useState(false);

  if (submenu) {
    return (
      <div
        className="menu-item has-submenu"
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => setOpen(false)}
      >
        {icon ? <span className="menu-icon">{icon}</span> : null}
        <span className="menu-label">
          {label}
          {hint ? <em>{hint}</em> : null}
        </span>
        {shortcut ? <kbd>{shortcut}</kbd> : null}
        <ChevronRightIcon size={13} />
        {open ? <div className="submenu">{submenu}</div> : null}
      </div>
    );
  }

  return (
    <button className="menu-item" role="menuitem" onClick={onClick}>
      {icon ? <span className="menu-icon">{icon}</span> : null}
      <span className="menu-label">
        {label}
        {hint ? <em>{hint}</em> : null}
      </span>
      {shortcut ? <kbd>{shortcut}</kbd> : null}
      {checked ? <CheckIcon size={13} /> : null}
    </button>
  );
}

export function MenuSeparator() {
  return <div className="menu-sep" />;
}

/** The composer's `+` menu: what can be brought into this message. */
export function AttachMenu({
  projects,
  skills,
  connectors,
  onAddImages,
  onAddFile,
  onAddToProject,
  onUseSkill,
  onManageSkills,
  onManageConnectors,
  canAddFile,
}: {
  projects: Project[];
  skills: SkillSummary[];
  connectors: ConnectorSummary[];
  onAddImages: () => void;
  onAddFile: () => void;
  onAddToProject: (project: Project) => void;
  onUseSkill: (skill: SkillSummary) => void;
  onManageSkills: () => void;
  onManageConnectors: () => void;
  /** Attaching a file needs a path, which only the desktop host can supply. */
  canAddFile: boolean;
}) {
  return (
    <>
      <MenuItem
        icon={<PaperclipIcon size={14} />}
        label="Add photos"
        onClick={onAddImages}
      />
      {canAddFile ? (
        <MenuItem icon={<ProjectIcon size={14} />} label="Add files" onClick={onAddFile} />
      ) : null}
      <MenuItem
        icon={<ProjectIcon size={14} />}
        label="Add to project"
        submenu={
          projects.length === 0 ? (
            <MenuItem label="No projects yet" />
          ) : (
            projects.map((project) => (
              <MenuItem
                key={project.id}
                label={project.name}
                onClick={() => onAddToProject(project)}
              />
            ))
          )
        }
      />

      <MenuSeparator />

      <MenuItem
        icon={<SkillIcon size={14} />}
        label="Skills"
        submenu={
          <>
            {skills.length === 0 ? (
              <MenuItem label="None available here" />
            ) : (
              skills
                .filter((skill) => skill.enabled)
                .slice(0, 12)
                .map((skill) => (
                  <MenuItem
                    key={skill.path || skill.name}
                    label={skill.name}
                    onClick={() => onUseSkill(skill)}
                  />
                ))
            )}
            <MenuSeparator />
            <MenuItem label="Manage skills" onClick={onManageSkills} />
          </>
        }
      />
      <MenuItem
        icon={<ConnectorIcon size={14} />}
        label="Connectors"
        submenu={
          <>
            {connectors.length === 0 ? (
              <MenuItem label="None configured" />
            ) : (
              connectors.map((connector) => (
                <MenuItem
                  key={connector.name}
                  label={connector.name}
                  hint={`${connector.toolCount} tools`}
                />
              ))
            )}
            <MenuSeparator />
            <MenuItem label="Manage connectors" onClick={onManageConnectors} />
          </>
        }
      />
    </>
  );
}

const EFFORTS: { value: ReasoningEffort; label: string; note?: string }[] = [
  { value: "low", label: "Low" },
  { value: "medium", label: "Medium", note: "Default" },
  { value: "high", label: "High" },
  { value: "xhigh", label: "Max" },
];

/**
 * The model menu: each model with what it is for, and the effort beneath.
 *
 * Only efforts the chosen model accepts are offered — offering one it ignores
 * would be a control that silently does nothing.
 */
export function ModelMenu({
  models,
  model,
  effort,
  onPickModel,
  onPickEffort,
}: {
  models: ModelOption[];
  model: string;
  effort?: ReasoningEffort;
  onPickModel: (model: string) => void;
  onPickEffort: (effort: ReasoningEffort) => void;
}) {
  const chosen = models.find((option) => option.model === model);
  const allowed = EFFORTS.filter((option) => chosen?.reasoningEfforts.includes(option.value));

  return (
    <>
      {models.length === 0 ? (
        <MenuItem label="No models configured" hint="Add them in config.toml" />
      ) : (
        models.map((option) => (
          <MenuItem
            key={option.id}
            label={option.displayName}
            hint={option.description}
            checked={option.model === model}
            onClick={() => onPickModel(option.model)}
          />
        ))
      )}

      {allowed.length > 0 ? (
        <>
          <MenuSeparator />
          <MenuItem
            label="Effort"
            hint={effort ? effort : undefined}
            submenu={
              <>
                <p className="menu-note">
                  Higher effort means more thorough responses, but takes longer.
                </p>
                {allowed.map((option) => (
                  <MenuItem
                    key={option.value}
                    label={option.label}
                    hint={option.note}
                    checked={effort === option.value}
                    onClick={() => onPickEffort(option.value)}
                  />
                ))}
              </>
            }
          />
        </>
      ) : null}
    </>
  );
}
