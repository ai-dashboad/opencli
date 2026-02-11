import { storageApi } from './storageApi';

export interface Asset {
  id: string;
  type: 'video' | 'image';
  title: string;
  url: string;
  thumbnail?: string;
  provider?: string;
  style?: string;
  createdAt: number;
}

// In-memory cache, synced with API
let _cache: Asset[] | null = null;

export async function getAssetsAsync(): Promise<Asset[]> {
  try {
    const rows = await storageApi.getAssets();
    _cache = rows.map((r: any) => ({
      id: r.id,
      type: r.type,
      title: r.title,
      url: r.url,
      thumbnail: r.thumbnail,
      provider: r.provider,
      style: r.style,
      createdAt: r.created_at ?? r.createdAt ?? Date.now(),
    }));
    return _cache;
  } catch {
    return _cache ?? [];
  }
}

// Synchronous fallback — returns cached data
export function getAssets(): Asset[] {
  if (_cache !== null) return _cache;
  // Trigger async load for next call
  getAssetsAsync().catch(() => {});
  return [];
}

export function saveAsset(partial: Omit<Asset, 'id' | 'createdAt'>): Asset {
  const asset: Asset = {
    ...partial,
    id: `asset_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    createdAt: Date.now(),
  };
  // Update cache immediately
  if (_cache) {
    _cache.unshift(asset);
    if (_cache.length > 100) _cache.length = 100;
  }
  // Persist to API (fire and forget)
  storageApi.saveAsset(asset).catch(() => {});
  return asset;
}

export function deleteAsset(id: string): void {
  if (_cache) {
    _cache = _cache.filter(a => a.id !== id);
  }
  storageApi.deleteAsset(id).catch(() => {});
}
