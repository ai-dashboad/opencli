import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { listPipelines, PipelineSummary } from '../api/pipeline-api';
import '../styles/home.css';

const QUICK_ACTIONS = [
  { icon: 'movie', label: 'Image to Video', path: '/create?mode=img2vid' },
  { icon: 'smart_display', label: 'Text to Video', path: '/create?mode=txt2vid' },
  { icon: 'image', label: 'Image Gen', path: '/create?mode=txt2img' },
  { icon: 'account_tree', label: 'Pipeline Editor', path: '/pipelines' },
  { icon: 'monitor_heart', label: 'System Status', path: '/status' },
];

const SHOWCASE = [
  { title: 'Cinematic Sunset', style: 'cinematic', provider: 'Replicate', gradient: 'linear-gradient(135deg, #e65c00, #f9d423)' },
  { title: 'Product Launch', style: 'adPromo', provider: 'Runway', gradient: 'linear-gradient(135deg, #6C5CE7, #a29bfe)' },
  { title: 'Social Reel', style: 'socialMedia', provider: 'Kling', gradient: 'linear-gradient(135deg, #00cec9, #81ecec)' },
  { title: 'Morning Calm', style: 'calmAesthetic', provider: 'Luma', gradient: 'linear-gradient(135deg, #fd79a8, #fdcb6e)' },
  { title: 'Mountain Epic', style: 'epic', provider: 'Replicate', gradient: 'linear-gradient(135deg, #0984e3, #74b9ff)' },
  { title: 'Noir Mystery', style: 'mysterious', provider: 'Runway', gradient: 'linear-gradient(135deg, #2d3436, #636e72)' },
];

function formatTimeAgo(dateString: string): string {
  const diff = Date.now() - new Date(dateString).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

export default function HomePage() {
  const navigate = useNavigate();
  const [prompt, setPrompt] = useState('');
  const [pipelines, setPipelines] = useState<PipelineSummary[]>([]);
  const [pipelinesLoaded, setPipelinesLoaded] = useState(false);

  useEffect(() => {
    listPipelines()
      .then((data) => {
        const sorted = [...data].sort(
          (a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime()
        );
        setPipelines(sorted.slice(0, 4));
      })
      .catch(() => {})
      .finally(() => setPipelinesLoaded(true));
  }, []);

  const handlePromptSubmit = () => {
    const target = prompt.trim()
      ? `/create?mode=txt2vid&prompt=${encodeURIComponent(prompt.trim())}`
      : '/create?mode=txt2vid';
    navigate(target);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handlePromptSubmit();
    }
  };

  return (
    <div className="hp-page">
      {/* Hero */}
      <div className="hp-hero">
        <h1 className="hp-hero-title">What do you want to create?</h1>
        <p className="hp-hero-subtitle">AI-powered video generation & editing</p>
        <div className="hp-hero-prompt">
          <textarea
            className="hp-hero-input"
            placeholder="Describe a video you want to generate..."
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            onKeyDown={handleKeyDown}
            rows={1}
          />
          <button className="hp-hero-submit" onClick={handlePromptSubmit}>
            <span className="material-icons">arrow_forward</span>
          </button>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="hp-quick-actions">
        {QUICK_ACTIONS.map((action) => (
          <Link key={action.label} to={action.path} className="hp-quick-card">
            <span className="material-icons">{action.icon}</span>
            {action.label}
          </Link>
        ))}
      </div>

      {/* Recent Pipelines */}
      <div className="hp-section">
        <div className="hp-section-header">
          <span className="hp-section-title">Recent Pipelines</span>
          <Link to="/pipelines" className="hp-section-link">View all &rarr;</Link>
        </div>
        {pipelinesLoaded && pipelines.length === 0 ? (
          <div className="hp-empty">
            No pipelines yet. <Link to="/pipelines">Create one &rarr;</Link>
          </div>
        ) : (
          <div className="hp-pipeline-grid">
            {pipelines.map((p) => (
              <Link key={p.id} to={`/pipelines/${p.id}`} className="hp-pipeline-card">
                <span className="hp-pipeline-name">{p.name}</span>
                <div className="hp-pipeline-meta">
                  <span>{p.node_count} nodes</span>
                  <span>{formatTimeAgo(p.updated_at)}</span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>

      {/* Showcase Gallery */}
      <div className="hp-section">
        <div className="hp-section-header">
          <span className="hp-section-title">Showcase</span>
        </div>
        <div className="hp-gallery-grid">
          {SHOWCASE.map((item) => (
            <div key={item.title} className="hp-gallery-item">
              <div className="hp-gallery-thumb" style={{ background: item.gradient }} />
              <div className="hp-gallery-info">
                <span className="hp-gallery-title">{item.title}</span>
                <div className="hp-gallery-badges">
                  <span className="hp-badge">{item.style}</span>
                  <span className="hp-badge provider">{item.provider}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
