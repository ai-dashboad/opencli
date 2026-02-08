/** Video pipeline port type → color mapping (tldraw-style). */
export const DATA_TYPE_COLORS: Record<string, string> = {
  model:     '#2563EB',  // Blue
  string:    '#16A34A',  // Green
  image:     '#DB2777',  // Pink
  video:     '#9333EA',  // Purple
  number:    '#EA580C',  // Orange
  control:   '#0891B2',  // Teal
  embedding: '#4F46E5',  // Indigo
  any:       '#6B7280',  // Gray
};

export function getTypeColor(type: string): string {
  return DATA_TYPE_COLORS[type] || DATA_TYPE_COLORS.any;
}

/** Convert daemon color (integer or hex string) to CSS hex. */
export function daemonColorToCss(color: string | number | undefined): string {
  if (color == null) return '#6B7280';
  if (typeof color === 'number') {
    return '#' + (color & 0xFFFFFF).toString(16).padStart(6, '0');
  }
  if (!color) return '#6B7280';
  const hex = color.replace(/^0x[fF]{2}/, '#');
  if (hex.startsWith('#')) return hex;
  return `#${color.slice(-6)}`;
}

/** Node type → icon character for video pipeline nodes. */
export const NODE_ICONS: Record<string, string> = {
  load_model:      '⊕',
  prompt:          '≡',
  load_image:      '⊞',
  number:          '#',
  generate:        '✱',
  concat:          '⊞',
  blend:           '◐',
  adjust:          '◑',
  upscale:         '⤢',
  style_transfer:  '⊛',
  controlnet:      '⊿',
  ip_adapter:      '⊙',
  output:          '▸',
};

export function getNodeIcon(nodeType: string): string {
  return NODE_ICONS[nodeType] || '•';
}
