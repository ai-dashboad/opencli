import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { listEpisodes, createEpisodeFromText, deleteEpisode, EpisodeSummary } from '../api/episode-api';
import ConfirmDialog from '../components/ConfirmDialog';
import { showToast } from '../components/Toast';
import '../styles/episodes.css';

export default function EpisodeEditor() {
  const navigate = useNavigate();
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [creating, setCreating] = useState(false);

  // Create form state
  const [narrativeText, setNarrativeText] = useState('');
  const [language, setLanguage] = useState('zh-CN');
  const [style, setStyle] = useState('anime');
  const [maxScenes, setMaxScenes] = useState(8);
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null);

  const fetchEpisodes = useCallback(async () => {
    try {
      const list = await listEpisodes();
      setEpisodes(list);
    } catch (e) {
      console.error('Failed to load episodes:', e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchEpisodes(); }, [fetchEpisodes]);

  const handleCreate = async () => {
    if (!narrativeText.trim()) return;
    setCreating(true);
    try {
      const result = await createEpisodeFromText(narrativeText, { language, style, maxScenes });
      if (result.success && result.id) {
        setShowCreate(false);
        setNarrativeText('');
        navigate(`/episodes/${result.id}`);
      }
    } catch (e) {
      console.error('Create failed:', e);
    } finally {
      setCreating(false);
    }
  };

  const handleDeleteClick = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    setDeleteTarget(id);
  };

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    await deleteEpisode(deleteTarget);
    setEpisodes((prev) => prev.filter((ep) => ep.id !== deleteTarget));
    showToast('Episode deleted', 'success');
    setDeleteTarget(null);
  };

  const formatDate = (ts: number) => {
    if (!ts) return '';
    return new Date(ts).toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  };

  return (
    <div className="page-episodes">
      <h1>Episodes</h1>
      <p className="page-subtitle">AI-generated anime episode pipeline</p>

      <div className="episodes-toolbar">
        <button className="primary" onClick={() => setShowCreate(true)}>
          <span className="material-icons" style={{ fontSize: 18 }}>add</span>
          New Episode
        </button>
        <button onClick={fetchEpisodes}>
          <span className="material-icons" style={{ fontSize: 18 }}>refresh</span>
          Refresh
        </button>
      </div>

      {loading ? (
        <p style={{ color: 'var(--text-secondary)' }}>Loading episodes...</p>
      ) : episodes.length === 0 ? (
        <div className="empty-state">
          <span className="material-icons">theaters</span>
          <h3>No episodes yet</h3>
          <p>Create your first AI-generated anime episode from narrative text.</p>
        </div>
      ) : (
        <div className="episode-grid">
          {episodes.map((ep) => (
            <div key={ep.id} className="episode-card" onClick={() => navigate(`/episodes/${ep.id}`)}>
              <h3>{ep.title || 'Untitled Episode'}</h3>
              <p className="synopsis">{ep.synopsis || 'No synopsis'}</p>
              <div className="card-meta">
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span className={`episode-status ${ep.status}`}>{ep.status}</span>
                  {ep.pipeline_id && (
                    <span style={{
                      display: 'inline-flex', alignItems: 'center', gap: 3,
                      padding: '2px 8px', borderRadius: 10, fontSize: '0.7rem',
                      background: 'rgba(99,102,241,0.15)', color: '#818CF8',
                      border: '1px solid rgba(99,102,241,0.25)',
                    }}>
                      <span className="material-icons" style={{ fontSize: 11 }}>account_tree</span>
                      Pipeline
                    </span>
                  )}
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span className="card-date">{formatDate(ep.created_at)}</span>
                  <button className="delete-btn" onClick={(e) => handleDeleteClick(e, ep.id)} title="Delete">
                    <span className="material-icons" style={{ fontSize: 16 }}>delete_outline</span>
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <ConfirmDialog
        open={!!deleteTarget}
        title="Delete Episode"
        message="This episode and all its generated content will be permanently deleted."
        confirmLabel="Delete"
        danger
        onConfirm={confirmDelete}
        onCancel={() => setDeleteTarget(null)}
      />

      {showCreate && (
        <div className="modal-overlay" onClick={() => setShowCreate(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h2>Create Episode from Narrative</h2>
            <label>Story / Narrative Text</label>
            <textarea
              value={narrativeText}
              onChange={(e) => setNarrativeText(e.target.value)}
              placeholder="Paste your story here. AI will generate scenes, dialogue, and visual prompts..."
            />
            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: 1 }}>
                <label>Language</label>
                <select value={language} onChange={(e) => setLanguage(e.target.value)}>
                  <option value="zh-CN">Chinese (Simplified)</option>
                  <option value="ja-JP">Japanese</option>
                  <option value="en-US">English</option>
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label>Style</label>
                <select value={style} onChange={(e) => setStyle(e.target.value)}>
                  <option value="anime">Anime</option>
                  <option value="realistic">Realistic</option>
                  <option value="comic">Comic</option>
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label>Max Scenes</label>
                <input type="number" value={maxScenes} min={2} max={20} onChange={(e) => setMaxScenes(Number(e.target.value))} />
              </div>
            </div>
            <div className="modal-actions">
              <button onClick={() => setShowCreate(false)}>Cancel</button>
              <button className="primary" onClick={handleCreate} disabled={creating || !narrativeText.trim()}>
                {creating ? 'Generating Script...' : 'Generate Episode Script'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
