import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { listEpisodes, createEpisodeFromText, deleteEpisode, EpisodeSummary } from '../api/episode-api';
import ConfirmDialog from '../components/ConfirmDialog';
import { showToast } from '../components/Toast';
import '../styles/episodes.css';

type StatusFilter = 'all' | 'draft' | 'generating' | 'completed' | 'failed';

const STATUS_LABELS: Record<string, string> = {
  draft: '草稿',
  generating: '生成中',
  completed: '已完成',
  failed: '失败',
};

const GRADIENTS = [
  'linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)',
  'linear-gradient(135deg, #0d0d0d 0%, #1a0a2e 50%, #2d1b69 100%)',
  'linear-gradient(135deg, #1a1a1a 0%, #2d1f3d 50%, #1a3a2a 100%)',
  'linear-gradient(135deg, #0a0a0a 0%, #1a2a3a 50%, #0a2a4a 100%)',
  'linear-gradient(135deg, #1a0a0a 0%, #2a1a1a 50%, #3a1a2a 100%)',
];

export default function EpisodeEditor() {
  const navigate = useNavigate();
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<StatusFilter>('all');
  const [showCreate, setShowCreate] = useState(false);
  const [creating, setCreating] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null);

  // Create form state
  const [narrativeText, setNarrativeText] = useState('');
  const [language, setLanguage] = useState('zh-CN');
  const [style, setStyle] = useState('anime');
  const [maxScenes, setMaxScenes] = useState(8);

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

  // Auto-refresh generating episodes
  useEffect(() => {
    const hasGenerating = episodes.some(ep => ep.status === 'generating');
    if (!hasGenerating) return;
    const interval = setInterval(fetchEpisodes, 3000);
    return () => clearInterval(interval);
  }, [episodes, fetchEpisodes]);

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

  const filtered = filter === 'all' ? episodes : episodes.filter(ep => ep.status === filter);
  const counts = {
    all: episodes.length,
    draft: episodes.filter(ep => ep.status === 'draft').length,
    generating: episodes.filter(ep => ep.status === 'generating').length,
    completed: episodes.filter(ep => ep.status === 'completed').length,
    failed: episodes.filter(ep => ep.status === 'failed').length,
  };

  const formatDate = (ts: number) => {
    if (!ts) return '';
    const diff = Date.now() - ts;
    if (diff < 60000) return '刚刚';
    if (diff < 3600000) return `${Math.floor(diff / 60000)} 分钟前`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)} 小时前`;
    return new Date(ts).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
  };

  const getThumbnailUrl = (ep: EpisodeSummary) => {
    if (ep.output_path) {
      // Use the video file URL as poster source
      return ep.output_path;
    }
    return null;
  };

  return (
    <div className="page-episodes">
      <div className="ep-header">
        <div>
          <h1>我的作品</h1>
          <p className="page-subtitle">AI 动漫 / 仙侠短片工作台</p>
        </div>
        <button className="ep-create-btn" onClick={() => setShowCreate(true)}>
          <span className="material-icons">add</span>
          新建作品
        </button>
      </div>

      {/* Status filter chips */}
      <div className="ep-filters">
        {(['all', 'draft', 'generating', 'completed', 'failed'] as StatusFilter[]).map(f => (
          <button
            key={f}
            className={`ep-filter-chip${filter === f ? ' active' : ''}`}
            onClick={() => setFilter(f)}
          >
            {f === 'all' ? '全部' : STATUS_LABELS[f]}
            <span className="ep-filter-count">{counts[f]}</span>
          </button>
        ))}
      </div>

      {/* Quick entry points */}
      {episodes.length > 0 && (
        <div className="ep-quick-entries">
          <button className="ep-quick-btn" onClick={() => setShowCreate(true)}>
            <span className="material-icons">edit_note</span>
            文字成片
          </button>
          <button className="ep-quick-btn" onClick={() => setShowCreate(true)}>
            <span className="material-icons">description</span>
            剧本导入
          </button>
          <button className="ep-quick-btn" onClick={() => setShowCreate(true)}>
            <span className="material-icons">collections</span>
            图片成片
          </button>
        </div>
      )}

      {loading ? (
        <div className="ep-loading">
          <span className="material-icons ep-spin">autorenew</span>
          加载中...
        </div>
      ) : filtered.length === 0 ? (
        <div className="ep-empty">
          <span className="material-icons ep-empty-icon">theaters</span>
          <h3>{filter === 'all' ? '还没有作品' : `没有${STATUS_LABELS[filter] || ''}的作品`}</h3>
          <p>从一段故事文字开始，AI 自动生成场景、对白和画面</p>
          {filter === 'all' && (
            <div className="ep-empty-actions">
              <button className="ep-create-btn" onClick={() => setShowCreate(true)}>
                <span className="material-icons">edit_note</span>
                文字成片
              </button>
            </div>
          )}
        </div>
      ) : (
        <div className="ep-grid">
          {filtered.map((ep, idx) => {
            const thumbUrl = getThumbnailUrl(ep);
            return (
              <div key={ep.id} className="ep-card" onClick={() => navigate(`/episodes/${ep.id}`)}>
                {/* Thumbnail area */}
                <div className="ep-card-thumb">
                  {thumbUrl && ep.status === 'completed' ? (
                    <video src={thumbUrl} className="ep-thumb-media" muted preload="metadata" />
                  ) : (
                    <div className="ep-thumb-placeholder" style={{ background: GRADIENTS[idx % GRADIENTS.length] }}>
                      <span className="material-icons">
                        {ep.status === 'generating' ? 'auto_awesome' : 'movie_creation'}
                      </span>
                    </div>
                  )}
                  {/* Status badge */}
                  <span className={`ep-card-status ${ep.status}`}>
                    {ep.status === 'generating' && <span className="material-icons ep-spin" style={{ fontSize: 12 }}>autorenew</span>}
                    {STATUS_LABELS[ep.status] || ep.status}
                  </span>
                  {/* Duration for completed */}
                  {ep.status === 'completed' && (
                    <span className="ep-card-duration">
                      <span className="material-icons" style={{ fontSize: 12 }}>play_arrow</span>
                    </span>
                  )}
                </div>

                {/* Generating progress bar */}
                {ep.status === 'generating' && (
                  <div className="ep-card-progress">
                    <div className="ep-card-progress-fill" style={{ width: `${Math.round((ep.progress || 0) * 100)}%` }} />
                  </div>
                )}

                {/* Info */}
                <div className="ep-card-info">
                  <h3 className="ep-card-title">{ep.title || '未命名作品'}</h3>
                  <p className="ep-card-synopsis">{ep.synopsis || '暂无简介'}</p>
                  <div className="ep-card-footer">
                    <span className="ep-card-date">{formatDate(ep.created_at)}</span>
                    <button className="ep-card-delete" onClick={(e) => handleDeleteClick(e, ep.id)} title="删除">
                      <span className="material-icons">delete_outline</span>
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <ConfirmDialog
        open={!!deleteTarget}
        title="删除作品"
        message="该作品及其所有生成内容将被永久删除，此操作不可撤销。"
        confirmLabel="删除"
        danger
        onConfirm={confirmDelete}
        onCancel={() => setDeleteTarget(null)}
      />

      {showCreate && (
        <div className="modal-overlay" onClick={() => setShowCreate(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h2>文字成片</h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', margin: '0 0 16px' }}>
              粘贴故事文本，AI 自动拆分场景、生成对白和视觉描述
            </p>
            <label>故事 / 剧情文本</label>
            <textarea
              value={narrativeText}
              onChange={(e) => setNarrativeText(e.target.value)}
              placeholder="在此粘贴你的故事...&#10;&#10;例如：林远踏入幽暗森林，前方妖气弥漫。小雪紧随其后，手握灵剑，警惕地望向四周..."
              rows={6}
            />
            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: 1 }}>
                <label>语言</label>
                <select value={language} onChange={(e) => setLanguage(e.target.value)}>
                  <option value="zh-CN">中文</option>
                  <option value="ja-JP">日本語</option>
                  <option value="en-US">English</option>
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label>风格</label>
                <select value={style} onChange={(e) => setStyle(e.target.value)}>
                  <option value="anime">动漫</option>
                  <option value="xianxia">仙侠</option>
                  <option value="realistic">写实</option>
                  <option value="comic">漫画</option>
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label>场景上限</label>
                <input type="number" value={maxScenes} min={2} max={20} onChange={(e) => setMaxScenes(Number(e.target.value))} />
              </div>
            </div>
            <div className="modal-actions">
              <button onClick={() => setShowCreate(false)}>取消</button>
              <button className="primary" onClick={handleCreate} disabled={creating || !narrativeText.trim()}>
                {creating ? '正在生成剧本...' : '生成剧本'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
