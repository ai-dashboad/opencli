import { useEffect, useLayoutEffect, useRef, useState } from "react";
import type {
  ApprovalPolicy,
  ConnectorSummary,
  ModelOption,
  Project,
  ReasoningEffort,
  SkillSummary,
} from "./protocol";
import {
  BoltIcon,
  CheckIcon,
  ChevronRightIcon,
  CloseIcon,
  ConnectorIcon,
  FastForwardIcon,
  GitHubIcon,
  HandIcon,
  PaperclipIcon,
  PlugIcon,
  ProjectIcon,
  SkillIcon,
} from "./icons";

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
  wide = false,
  children,
}: {
  open: boolean;
  onClose: () => void;
  align?: "left" | "right";
  /**
   * For a menu whose rows carry a sentence each.
   *
   * At the usual width a title wrapped onto two lines and its description onto
   * four, so three choices of similar length became three blocks of different
   * heights and nothing could be compared at a glance.
   */
  wide?: boolean;
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
    <div className={`popover ${align}${wide ? " wide" : ""}`} ref={ref} role="menu">
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
  const [flip, setFlip] = useState(false);
  const [lift, setLift] = useState(0);
  const panel = useRef<HTMLDivElement>(null);

  // A hint that is a sentence is a description and wraps; one that is a bare
  // value sits on the same line and is clipped if it must be. Told apart by
  // whether it reads as prose, because the caller should not have to say.
  const describes = !!hint && (hint.includes(" ") || hint.length > 16);

  // A submenu opens to the right, which runs off the screen when its parent is
  // already near the edge. Measure once it is on screen and swap sides —
  // guessing from the parent's alignment gets it wrong as soon as the window
  // is resized.
  useLayoutEffect(() => {
    if (!open || !panel.current) return;
    const rect = panel.current.getBoundingClientRect();
    setFlip(rect.right > window.innerWidth - 8);
    // A submenu is anchored to its row, so a row near the top of the screen
    // pushes it off the top. Nudge it down by exactly the amount that escapes.
    const escapes = 8 - rect.top;
    setLift(escapes > 0 ? escapes : 0);
  }, [open]);

  if (submenu) {
    return (
      <div
        className="menu-item has-submenu"
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => {
          setOpen(false);
          setFlip(false);
          setLift(0);
        }}
      >
        {icon ? <span className="menu-icon">{icon}</span> : null}
        <span className="menu-label">
          {label}
          {hint ? <em className="value">{hint}</em> : null}
        </span>
        {shortcut ? <kbd>{shortcut}</kbd> : null}
        <ChevronRightIcon size={13} />
        {open ? (
          <div
            className={`submenu${flip ? " flip" : ""}`}
            ref={panel}
            style={lift ? { transform: `translateY(${lift}px)` } : undefined}
          >
            {submenu}
          </div>
        ) : null}
      </div>
    );
  }

  return (
    <button
      className={`menu-item${checked ? " chosen" : ""}${describes ? " tall" : ""}`}
      role="menuitemradio"
      aria-checked={checked ?? false}
      onClick={onClick}
    >
      {icon ? <span className="menu-icon">{icon}</span> : null}
      <span className="menu-label">
        {describes ? <strong>{label}</strong> : label}
        {hint ? <em className={describes ? undefined : "value"}>{hint}</em> : null}
      </span>
      {shortcut ? <kbd>{shortcut}</kbd> : null}
      {checked ? <CheckIcon size={13} /> : null}
    </button>
  );
}

export function MenuSeparator() {
  return <div className="menu-sep" />;
}

/** A row that toggles something, with the state shown as a switch. */
export function MenuToggle({
  label,
  hint,
  checked,
  onChange,
}: {
  label: string;
  hint?: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="menu-item toggle">
      <span className="menu-label">
        {label}
        {hint ? <em>{hint}</em> : null}
      </span>
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
      />
      <span className="switch" aria-hidden="true" />
    </label>
  );
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
  onRecordSkill,
  onManageConnectors,
  onBrowsePlugins,
  onCloneRepo,
  webSearch,
  research,
  onToggleWebSearch,
  onToggleResearch,
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
  onRecordSkill: () => void;
  onManageConnectors: () => void;
  onBrowsePlugins: () => void;
  onCloneRepo: () => void;
  webSearch: boolean;
  research: boolean;
  onToggleWebSearch: (on: boolean) => void;
  onToggleResearch: (on: boolean) => void;
  /** Attaching a file needs a path, which only the desktop host can supply. */
  canAddFile: boolean;
}) {
  return (
    <>
      <MenuItem
        icon={<PaperclipIcon size={14} />}
        label="Add files or photos"
        shortcut="⌘U"
        onClick={onAddImages}
      />
      {canAddFile ? (
        <MenuItem icon={<ProjectIcon size={14} />} label="Add files" onClick={onAddFile} />
      ) : null}
      <MenuItem
        icon={<GitHubIcon size={14} />}
        label="Add from GitHub"
        onClick={onCloneRepo}
      />
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
            <MenuItem label="Record a skill" onClick={onRecordSkill} />
            <MenuItem label="Manage skills" onClick={onManageSkills} />
            <MenuItem label="Browse skills" onClick={onBrowsePlugins} />
          </>
        }
      />
      <MenuItem
        icon={<PlugIcon size={14} />}
        label="Add plugins…"
        onClick={onBrowsePlugins}
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

      <MenuSeparator />

      <MenuToggle
        label="Research"
        hint="Investigate thoroughly across sources before answering"
        checked={research}
        onChange={onToggleResearch}
      />
      <MenuToggle
        label="Web search"
        hint="Run by the model provider, not by OpenCLI"
        checked={webSearch}
        onChange={onToggleWebSearch}
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
/**
 * When the agent stops to ask, as a choice made where the work happens.
 *
 * The same setting exists in Customize, but a run of commands is exactly when
 * someone decides they have seen enough of them — and walking to another panel
 * to say so, then starting a new chat for it to take effect, is long enough
 * that they approve twenty more instead.
 *
 * `on-request` is not offered here for the same reason it is not offered
 * there: it leaves the decision to the model, which in practice almost never
 * asks, so it reads as "never" to anyone who chose it expecting to be asked.
 *
 * The label is a word and the hint is the sentence, rather than the label
 * being the sentence and the hint repeating it. A list of three is scanned by
 * its labels; a label that is itself a paragraph gives the eye nothing to
 * land on, and the explanation underneath then says the same thing twice.
 */
export const APPROVAL_MODES: {
  value: ApprovalPolicy;
  label: string;
  hint: string;
  icon: () => React.ReactNode;
}[] = [
  {
    value: "untrusted",
    label: "Manual",
    hint: "Every command that is not known-safe is shown to you first.",
    icon: () => <HandIcon size={16} />,
  },
  {
    value: "on-failure",
    label: "Auto",
    hint: "Commands run without asking. You are stopped only when one needs more access.",
    icon: () => <BoltIcon size={16} />,
  },
  {
    value: "never",
    label: "Never ask",
    hint: "Nothing is shown before it runs. For a directory you would let a script loose in.",
    icon: () => <FastForwardIcon size={16} />,
  },
];

export function ApprovalMenu({
  policy,
  onPick,
}: {
  policy: ApprovalPolicy;
  onPick: (policy: ApprovalPolicy) => void;
}) {
  return (
    <>
      <div className="menu-head">
        <span>Modes</span>
        <em>Applies from your next message</em>
      </div>
      {APPROVAL_MODES.map((mode) => (
        <MenuItem
          key={mode.value}
          icon={mode.icon()}
          label={mode.label}
          hint={mode.hint}
          checked={policy === mode.value}
          onClick={() => onPick(mode.value)}
        />
      ))}
    </>
  );
}

export function ModelMenu({
  models,
  model,
  effort,
  showThinking,
  onPickModel,
  onPickEffort,
  onToggleThinking,
}: {
  models: ModelOption[];
  model: string;
  effort?: ReasoningEffort;
  showThinking: boolean;
  onPickModel: (model: string) => void;
  onPickEffort: (effort: ReasoningEffort) => void;
  onToggleThinking: (on: boolean) => void;
}) {
  const chosen = models.find((option) => option.model === model);
  const allowed = EFFORTS.filter((option) => chosen?.reasoningEfforts.includes(option.value));

  // A handful up front and the rest behind a submenu: a long flat list buries
  // the one being used. The chosen model is always in the short list, so it is
  // never hidden behind another click.
  const SHORT = 4;
  const ordered = chosen ? [chosen, ...models.filter((option) => option !== chosen)] : models;
  const primary = ordered.slice(0, SHORT);
  const rest = ordered.slice(SHORT);

  const row = (option: ModelOption) => (
    <MenuItem
      key={option.id}
      label={option.displayName}
      hint={option.description}
      checked={option.model === model}
      onClick={() => onPickModel(option.model)}
    />
  );

  return (
    <>
      {models.length === 0 ? (
        <MenuItem label="No models configured" hint="Add them in config.toml" />
      ) : (
        primary.map(row)
      )}

      {allowed.length > 0 ? (
        <>
          <MenuSeparator />
          <MenuItem
            label="Effort"
            hint={effort}
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
                <MenuSeparator />
                <MenuToggle
                  label="Show thinking"
                  hint="Ask for a summary of the model's reasoning"
                  checked={showThinking}
                  onChange={onToggleThinking}
                />
              </>
            }
          />
        </>
      ) : null}

      {rest.length > 0 ? (
        <>
          <MenuSeparator />
          <MenuItem label="More models" submenu={<>{rest.map(row)}</>} />
        </>
      ) : null}
    </>
  );
}

/**
 * A modal dialog.
 *
 * Used where a form would otherwise push the thing being looked at off the
 * screen. Closes on Escape and on a click outside — a dialog that can only be
 * dismissed by completing it traps anyone who opened it by accident.
 */
export function Dialog({
  open,
  title,
  onClose,
  footer,
  children,
}: {
  open: boolean;
  title: string;
  onClose: () => void;
  footer?: React.ReactNode;
  children: React.ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className="scrim" onMouseDown={onClose}>
      <div
        className="dialog"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className="dialog-head">
          <h3>{title}</h3>
          <button className="icon-button" aria-label="Close" onClick={onClose}>
            <CloseIcon size={15} />
          </button>
        </div>
        <div className="dialog-body">{children}</div>
        {footer ? <div className="dialog-foot">{footer}</div> : null}
      </div>
    </div>
  );
}
