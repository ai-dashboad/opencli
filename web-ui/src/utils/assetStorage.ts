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

const STORAGE_KEY = 'opencli_assets';

export function getAssets(): Asset[] {
  try {
    const data = localStorage.getItem(STORAGE_KEY);
    return data ? JSON.parse(data) : [];
  } catch {
    return [];
  }
}

export function saveAsset(partial: Omit<Asset, 'id' | 'createdAt'>): Asset {
  const assets = getAssets();
  const asset: Asset = {
    ...partial,
    id: `asset_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    createdAt: Date.now(),
  };
  assets.unshift(asset);
  if (assets.length > 100) assets.length = 100;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(assets));
  return asset;
}

export function deleteAsset(id: string): void {
  const assets = getAssets().filter(a => a.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(assets));
}
