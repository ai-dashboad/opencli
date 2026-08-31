/**
 * Line icons, drawn inline.
 *
 * Inline rather than from an icon package: there are barely a dozen, they all
 * share one stroke weight, and a dependency here would be larger than the
 * shapes it carries. `currentColor` lets each one inherit its row's state.
 */

interface IconProps {
  /** Square size in pixels. */
  size?: number;
}

function Svg({ size = 16, children }: IconProps & { children: React.ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.35"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {children}
    </svg>
  );
}

export function PlusIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M8 3.2v9.6M3.2 8h9.6" />
    </Svg>
  );
}

export function ProjectIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <rect x="2" y="3.5" width="12" height="9.5" rx="1.6" />
      <path d="M2 6.2h12M5.6 3.5v2.7" />
    </Svg>
  );
}

export function ArtifactIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M8 2.2 13.4 5v6L8 13.8 2.6 11V5z" />
      <path d="M2.6 5 8 7.8 13.4 5M8 7.8v6" />
    </Svg>
  );
}

export function ClockIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <circle cx="8" cy="8" r="5.8" />
      <path d="M8 4.8V8l2.2 1.4" />
    </Svg>
  );
}

export function DispatchIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <rect x="2.6" y="4.4" width="10.8" height="8.4" rx="1.6" />
      <path d="M5.6 4.4V3.2h4.8v1.2M6.4 8.4h3.2" />
    </Svg>
  );
}

export function SlidersIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M3 4.6h10M3 11.4h10" />
      <circle cx="6.2" cy="4.6" r="1.5" />
      <circle cx="10" cy="11.4" r="1.5" />
    </Svg>
  );
}

export function MemoryIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M8 2.8c-2.3 0-4.1 1.7-4.1 3.8 0 1 .4 1.9 1.1 2.6v2.2c0 1 .8 1.8 1.8 1.8h2.4c1 0 1.8-.8 1.8-1.8V9.2c.7-.7 1.1-1.6 1.1-2.6 0-2.1-1.8-3.8-4.1-3.8z" />
      <path d="M6.4 10.6h3.2" />
    </Svg>
  );
}

export function SkillIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M8 2.4 9.7 6l3.9.5-2.8 2.7.7 3.8L8 11.2l-3.5 1.8.7-3.8L2.4 6.5 6.3 6z" />
    </Svg>
  );
}

export function ConnectorIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M6.3 9.7 4.9 11a2.4 2.4 0 0 1-3.4-3.4l1.4-1.4M9.7 6.3 11.1 5a2.4 2.4 0 0 1 3.4 3.4l-1.4 1.4" />
      <path d="M6.2 9.8 9.8 6.2" />
    </Svg>
  );
}

export function SettingsIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <circle cx="8" cy="8" r="2.1" />
      <path d="M8 1.8v1.6M8 12.6v1.6M14.2 8h-1.6M3.4 8H1.8M12.4 3.6l-1.1 1.1M4.7 11.3l-1.1 1.1M12.4 12.4l-1.1-1.1M4.7 4.7 3.6 3.6" />
    </Svg>
  );
}

export function PaletteIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M8 2.2a5.8 5.8 0 0 0 0 11.6c.7 0 1.2-.6 1.2-1.2 0-.3-.1-.6-.3-.8-.2-.2-.3-.5-.3-.8 0-.7.5-1.2 1.2-1.2h1.4a2.6 2.6 0 0 0 2.6-2.6C13.8 4.4 11.2 2.2 8 2.2z" />
      <circle cx="5.4" cy="7" r=".8" fill="currentColor" stroke="none" />
      <circle cx="8" cy="5.2" r=".8" fill="currentColor" stroke="none" />
    </Svg>
  );
}

export function SearchIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <circle cx="7.2" cy="7.2" r="4.4" />
      <path d="m10.6 10.6 3 3" />
    </Svg>
  );
}

export function ChevronIcon({ size = 16, open = false }: IconProps & { open?: boolean }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.35"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      style={{ transform: open ? "rotate(180deg)" : undefined, transition: "transform .15s" }}
    >
      <path d="m4.6 6.4 3.4 3.4 3.4-3.4" />
    </svg>
  );
}

export function StopIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <circle cx="8" cy="8" r="6" />
      <rect x="5.9" y="5.9" width="4.2" height="4.2" rx=".8" fill="currentColor" />
    </Svg>
  );
}

export function SendIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M8 13V3M4 6.8 8 3l4 3.8" />
    </Svg>
  );
}

export function PanelIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <rect x="2" y="3" width="12" height="10" rx="1.6" />
      <path d="M10 3v10" />
    </Svg>
  );
}
