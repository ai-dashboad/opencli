import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { getAssetsAsync, deleteAsset, type Asset } from '../utils/assetStorage';
import '../styles/assets.css';

type FilterType = 'all' | 'video' | 'image';

export default function AssetsPage() {
  const [assets, setAssets] = useState<Asset[]>([]);
  const [filter, setFilter] = useState<FilterType>('all');
  const [previewAsset, setPreviewAsset] = useState<Asset | null>(null);

  useEffect(() => {
    getAssetsAsync().then(setAssets);
  }, []);

  const filtered = filter === 'all' ? assets : assets.filter(a => a.type === filter);

  const handleDelete = (id: string) => {
    deleteAsset(id);
    getAssetsAsync().then(setAssets);
    if (previewAsset?.id === id) setPreviewAsset(null);
  };

  const handleDownload = (asset: Asset) => {
    const a = document.createElement('a');
    a.href = asset.url;
    a.download = `${asset.title.replace(/\s+/g, '_')}.${asset.type === 'video' ? 'mp4' : 'png'}`;
    a.click();
  };

  const formatDate = (ts: number) => {
    const diff = Date.now() - ts;
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return new Date(ts).toLocaleDateString();
  };

  return (
    <div className="ap-page">
      <div className="ap-header">
        <h1>My Assets</h1>
        <span className="ap-count">{assets.length} items</span>
      </div>

      {/* Filter tabs */}
      <div className="ap-filters">
        {(['all', 'video', 'image'] as FilterType[]).map(f => (
          <button
            key={f}
            className={`ap-filter${filter === f ? ' active' : ''}`}
            onClick={() => setFilter(f)}
          >
            {f === 'all' ? 'All' : f === 'video' ? 'Videos' : 'Images'}
            <span className="ap-filter-count">
              {f === 'all' ? assets.length : assets.filter(a => a.type === f).length}
            </span>
          </button>
        ))}
      </div>

      {/* Asset grid or empty state */}
      {filtered.length === 0 ? (
        <div className="ap-empty">
          <span className="material-icons ap-empty-icon">
            {filter === 'video' ? 'movie' : filter === 'image' ? 'image' : 'folder_open'}
          </span>
          <p className="ap-empty-title">
            {filter === 'all' ? 'No assets yet' : `No ${filter}s yet`}
          </p>
          <p className="ap-empty-desc">
            Generated content will appear here.
          </p>
          <div className="ap-empty-actions">
            <Link to="/create?mode=txt2vid" className="ap-empty-btn">Create Video</Link>
            <Link to="/create?mode=txt2img" className="ap-empty-btn">Create Image</Link>
          </div>
        </div>
      ) : (
        <div className="ap-grid">
          {filtered.map(asset => (
            <div key={asset.id} className="ap-card" onClick={() => setPreviewAsset(asset)}>
              <div className="ap-card-thumb">
                {asset.type === 'video' ? (
                  <video src={asset.url} className="ap-thumb-media" muted />
                ) : (
                  <img src={asset.thumbnail || asset.url} alt={asset.title} className="ap-thumb-media" />
                )}
                <span className="ap-card-badge">{asset.type === 'video' ? 'VIDEO' : 'IMAGE'}</span>
              </div>
              <div className="ap-card-info">
                <span className="ap-card-title">{asset.title}</span>
                <div className="ap-card-meta">
                  {asset.provider && <span className="ap-card-provider">{asset.provider}</span>}
                  <span className="ap-card-date">{formatDate(asset.createdAt)}</span>
                </div>
              </div>
              <div className="ap-card-actions" onClick={e => e.stopPropagation()}>
                <button className="ap-card-btn" onClick={() => handleDownload(asset)} title="Download">
                  <span className="material-icons">download</span>
                </button>
                <button className="ap-card-btn delete" onClick={() => handleDelete(asset.id)} title="Delete">
                  <span className="material-icons">delete</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Preview Modal */}
      {previewAsset && (
        <div className="ap-modal-overlay" onClick={() => setPreviewAsset(null)}>
          <div className="ap-modal" onClick={e => e.stopPropagation()}>
            <button className="ap-modal-close" onClick={() => setPreviewAsset(null)}>&times;</button>
            <div className="ap-modal-media">
              {previewAsset.type === 'video' ? (
                <video src={previewAsset.url} controls autoPlay loop muted className="ap-modal-content" />
              ) : (
                <img src={previewAsset.url} alt={previewAsset.title} className="ap-modal-content" />
              )}
            </div>
            <div className="ap-modal-info">
              <h3>{previewAsset.title}</h3>
              <div className="ap-modal-meta">
                {previewAsset.provider && <span>Provider: {previewAsset.provider}</span>}
                {previewAsset.style && <span>Style: {previewAsset.style}</span>}
                <span>{formatDate(previewAsset.createdAt)}</span>
              </div>
              <div className="ap-modal-actions">
                <button className="ap-action-btn primary" onClick={() => handleDownload(previewAsset)}>Download</button>
                <button className="ap-action-btn" onClick={() => { handleDelete(previewAsset.id); setPreviewAsset(null); }}>Delete</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
