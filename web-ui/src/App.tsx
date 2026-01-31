import { useState, useEffect } from 'react';
import ChatPanel from './components/ChatPanel';
import ModelSelector from './components/ModelSelector';
import QuickActions from './components/QuickActions';
import StatsPanel from './components/StatsPanel';
import { OpenCliClient } from './api/client';
import './App.css';

function App() {
  const [client] = useState(() => new OpenCliClient('ws://localhost:9529/api/v1/stream'));
  const [selectedModel, setSelectedModel] = useState('claude');
  const [connected, setConnected] = useState(false);
  const [stats, setStats] = useState<any>(null);

  useEffect(() => {
    // Connect to OpenCLI daemon
    client.connect().then(() => {
      setConnected(true);
      loadStats();
    }).catch((err) => {
      console.error('Failed to connect:', err);
    });

    // Load stats every 10 seconds
    const interval = setInterval(loadStats, 10000);
    return () => clearInterval(interval);
  }, [client]);

  const loadStats = async () => {
    try {
      const response = await fetch('http://localhost:9529/api/v1/stats');
      const data = await response.json();
      setStats(data);
    } catch (err) {
      console.error('Failed to load stats:', err);
    }
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>🚀 OpenCLI</h1>
        <div className="header-controls">
          <ModelSelector value={selectedModel} onChange={setSelectedModel} />
          <div className={`status ${connected ? 'connected' : 'disconnected'}`}>
            {connected ? '● Connected' : '○ Disconnected'}
          </div>
        </div>
      </header>

      <div className="app-content">
        <aside className="sidebar">
          <QuickActions client={client} />
          {stats && <StatsPanel stats={stats} />}
        </aside>

        <main className="main-content">
          <ChatPanel client={client} model={selectedModel} />
        </main>
      </div>
    </div>
  );
}

export default App;
