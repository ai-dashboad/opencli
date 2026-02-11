const API_BASE = 'http://localhost:9529/api/v1';

const headers = { 'Content-Type': 'application/json' };

async function fetchJson(url: string, options?: RequestInit) {
  const res = await fetch(url, { ...options, headers });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export const storageApi = {
  // ── Assets ──
  getAssets: (limit = 100) =>
    fetchJson(`${API_BASE}/assets?limit=${limit}`).then(d => d.assets ?? []),

  saveAsset: (asset: {
    id?: string;
    type: string;
    title: string;
    url: string;
    thumbnail?: string;
    provider?: string;
    style?: string;
    createdAt?: number;
  }) =>
    fetchJson(`${API_BASE}/assets`, {
      method: 'POST',
      body: JSON.stringify({
        id: asset.id ?? `asset_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        type: asset.type,
        title: asset.title,
        url: asset.url,
        thumbnail: asset.thumbnail,
        provider: asset.provider,
        style: asset.style,
        created_at: asset.createdAt ?? Date.now(),
      }),
    }),

  deleteAsset: (id: string) =>
    fetchJson(`${API_BASE}/assets/${id}`, { method: 'DELETE' }),

  // ── Generation History ──
  getHistory: (limit = 50) =>
    fetchJson(`${API_BASE}/history?limit=${limit}`).then(d => d.history ?? []),

  addHistory: (item: {
    id?: string;
    mode: string;
    prompt: string;
    provider: string;
    style?: string;
    resultType: string;
    thumbnail?: string;
    timestamp?: number;
  }) =>
    fetchJson(`${API_BASE}/history`, {
      method: 'POST',
      body: JSON.stringify({
        id: item.id ?? `h_${Date.now()}`,
        mode: item.mode,
        prompt: item.prompt,
        provider: item.provider,
        style: item.style ?? '',
        result_type: item.resultType,
        thumbnail: item.thumbnail,
        created_at: item.timestamp ?? Date.now(),
      }),
    }),

  deleteHistory: (id: string) =>
    fetchJson(`${API_BASE}/history/${id}`, { method: 'DELETE' }),

  clearHistory: () =>
    fetchJson(`${API_BASE}/history`, { method: 'DELETE' }),

  // ── Status Events ──
  getEvents: (limit = 100) =>
    fetchJson(`${API_BASE}/events?limit=${limit}`).then(d => d.events ?? []),

  logEvent: (event: {
    id?: string;
    type: string;
    source?: string;
    content: string;
    taskType?: string;
    status?: string;
    result?: any;
    timestamp?: number;
  }) =>
    fetchJson(`${API_BASE}/events`, {
      method: 'POST',
      body: JSON.stringify({
        id: event.id ?? `evt_${Date.now()}`,
        type: event.type,
        source: event.source ?? '',
        content: event.content,
        task_type: event.taskType,
        status: event.status,
        result: event.result,
        created_at: event.timestamp ?? Date.now(),
      }),
    }).catch(() => {}), // Fire-and-forget for events

  getEventStats: () =>
    fetchJson(`${API_BASE}/events/stats`),

  // ── Chat Messages ──
  getMessages: (limit = 100) =>
    fetchJson(`${API_BASE}/chat/messages?limit=${limit}`).then(d => d.messages ?? []),

  saveMessage: (msg: {
    id?: string;
    content: string;
    isUser: boolean;
    timestamp?: number;
    status?: string;
    taskType?: string;
    result?: any;
  }) =>
    fetchJson(`${API_BASE}/chat/messages`, {
      method: 'POST',
      body: JSON.stringify({
        id: msg.id ?? `msg_${Date.now()}`,
        content: msg.content,
        is_user: msg.isUser,
        timestamp: msg.timestamp ?? Date.now(),
        status: msg.status ?? 'completed',
        task_type: msg.taskType,
        result: msg.result,
      }),
    }),

  clearMessages: () =>
    fetchJson(`${API_BASE}/chat/messages`, { method: 'DELETE' }),
};
