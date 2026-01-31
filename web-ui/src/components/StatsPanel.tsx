import './StatsPanel.css';

interface StatsPanelProps {
  stats: {
    uptime_seconds: number;
    total_requests: number;
    cache_hit_rate: number;
    memory_mb: number;
    plugins_loaded: number;
  };
}

export default function StatsPanel({ stats }: StatsPanelProps) {
  const formatUptime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  };

  return (
    <div className="stats-panel">
      <h3>Statistics</h3>

      <div className="stat">
        <span className="label">Uptime:</span>
        <span className="value">{formatUptime(stats.uptime_seconds)}</span>
      </div>

      <div className="stat">
        <span className="label">Requests:</span>
        <span className="value">{stats.total_requests.toLocaleString()}</span>
      </div>

      <div className="stat">
        <span className="label">Cache Hit Rate:</span>
        <span className="value">{(stats.cache_hit_rate * 100).toFixed(1)}%</span>
      </div>

      <div className="stat">
        <span className="label">Memory:</span>
        <span className="value">{stats.memory_mb.toFixed(1)} MB</span>
      </div>

      <div className="stat">
        <span className="label">Plugins:</span>
        <span className="value">{stats.plugins_loaded}</span>
      </div>
    </div>
  );
}
