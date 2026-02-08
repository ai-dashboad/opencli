/** Data type → color mapping for port handles and edges. */
export const DATA_TYPE_COLORS: Record<string, string> = {
  string: '#4CAF50',
  number: '#2196F3',
  boolean: '#FF9800',
  image: '#E91E63',
  file: '#9C27B0',
  any: '#00BCD4',
};

/** Return CSS color for a given data type. */
export function getTypeColor(type: string): string {
  return DATA_TYPE_COLORS[type] || DATA_TYPE_COLORS.any;
}

/** Convert daemon hex color (e.g. '0xFF03A9F4') to CSS hex (#03A9F4). */
export function daemonColorToCss(color: string): string {
  if (!color) return '#666';
  // Strip '0xFF' prefix
  const hex = color.replace(/^0x[fF]{2}/, '#');
  if (hex.startsWith('#')) return hex;
  return `#${color.slice(-6)}`;
}

/** Map domain IDs to Material Icons names. */
export const DOMAIN_ICONS: Record<string, string> = {
  weather: 'wb_sunny',
  calculator: 'calculate',
  timer: 'timer',
  system: 'terminal',
  music: 'music_note',
  reminders: 'checklist',
  calendar: 'calendar_month',
  notes: 'sticky_note_2',
  media: 'perm_media',
  timezone: 'schedule',
  knowledge: 'school',
  contacts: 'contacts',
  ai: 'smart_toy',
};

export function getDomainIcon(domain: string): string {
  return DOMAIN_ICONS[domain] || 'extension';
}
