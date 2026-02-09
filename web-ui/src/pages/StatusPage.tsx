import { useState, useEffect, useRef } from 'react';
import { storageApi } from '../utils/storageApi';
import '../styles/status.css';

interface DaemonStatus {
  daemon: {
    version: string;
    uptime_seconds: number;
    memory_mb: number;
    plugins_loaded: number;
    total_requests: number;
  };
  mobile: {
    connected_clients: number;
    client_ids: string[];
  };
  timestamp: string;
}

interface Message {
  id: string;
  type: 'user' | 'system' | 'task_submit' | 'task_update' | 'task_result';
  source: string;
  content: string;
  taskType?: string;
  taskData?: any;
  status?: string;
  result?: any;
  timestamp: Date;
}

interface DeviceInfo {
  id: string;
  type: 'ios' | 'web';
  angle: number;
  distance: number;
  lastSeen: Date;
}

function StatusPage() {
  const [status, setStatus] = useState<DaemonStatus | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [connected, setConnected] = useState(false);
  const [wsConnected, setWsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [devices, setDevices] = useState<DeviceInfo[]>([]);
  const messagesTopRef = useRef<HTMLDivElement>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const radarCanvasRef = useRef<HTMLCanvasElement>(null);

  const scrollToTop = () => {
    messagesTopRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToTop();
  }, [messages]);

  // Load persisted events on mount
  useEffect(() => {
    storageApi.getEvents(100).then((events: any[]) => {
      const loaded: Message[] = events.map((e: any) => ({
        id: e.id,
        type: e.type || 'system',
        source: e.source || '',
        content: e.content || '',
        taskType: e.task_type,
        status: e.status,
        result: e.result ? (typeof e.result === 'string' ? JSON.parse(e.result) : e.result) : undefined,
        timestamp: new Date(e.created_at),
      }));
      if (loaded.length > 0) {
        setMessages(loaded.reverse());
      }
    }).catch(() => {});
  }, []);

  useEffect(() => {
    loadStatus();
    const interval = setInterval(loadStatus, 3000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    connectWebSocket();
    return () => {
      wsRef.current?.close();
    };
  }, []);

  const loadStatus = async () => {
    try {
      const response = await fetch('http://localhost:9875/status');
      if (!response.ok) throw new Error('Failed to fetch status');
      const data = await response.json();
      setStatus(data);
      setConnected(true);
      setError(null);
    } catch (err) {
      console.error('Failed to load status:', err);
      setConnected(false);
      setError(err instanceof Error ? err.message : 'Unknown error');
    }
  };

  const connectWebSocket = () => {
    try {
      const ws = new WebSocket('ws://localhost:9876');
      wsRef.current = ws;

      ws.onopen = async () => {
        console.log('WebSocket connected');
        setWsConnected(true);
        addSystemMessage('Connected to OpenCLI Daemon', 'system');

        const timestamp = Date.now();
        const token = await generateAuthToken('web_dashboard', timestamp);
        ws.send(JSON.stringify({
          type: 'auth',
          device_id: 'web_dashboard',
          token: token,
          timestamp: timestamp,
        }));
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          handleWebSocketMessage(data);
        } catch (e) {
          console.error('Failed to parse WebSocket message:', e);
        }
      };

      ws.onclose = () => {
        console.log('WebSocket disconnected');
        setWsConnected(false);
        addSystemMessage('Disconnected from Daemon', 'system');
        setTimeout(connectWebSocket, 5000);
      };

      ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        setWsConnected(false);
      };
    } catch (err) {
      console.error('Failed to connect WebSocket:', err);
      setWsConnected(false);
    }
  };

  const generateAuthToken = async (deviceId: string, timestamp: number): Promise<string> => {
    const input = `${deviceId}:${timestamp}:opencli-dev-secret`;
    const encoder = new TextEncoder();
    const data = encoder.encode(input);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    return hashHex;
  };

  const handleWebSocketMessage = (data: any) => {
    const type = data.type;

    switch (type) {
      case 'auth_success':
        addSystemMessage('Auth success, listening...', 'system');
        updateDeviceActivity('web_dashboard');
        break;

      case 'task_submitted':
        updateDeviceActivity(data.device_id);

        const userInput = data.task_data?._user_input;
        const displayContent = userInput
          ? `${userInput}`
          : `Task: ${data.task_type}`;

        addMessage({
          id: `task_${Date.now()}`,
          type: 'task_submit',
          source: data.device_id || 'unknown',
          content: displayContent,
          taskType: data.task_type,
          taskData: data.task_data,
          timestamp: new Date(),
        });
        break;

      case 'task_update':
        const status = data.status;
        const emoji = status === 'completed' ? '✅' : status === 'failed' ? '❌' : '⏳';

        addMessage({
          id: `update_${Date.now()}`,
          type: 'task_update',
          source: data.device_id || 'daemon',
          content: `${emoji} Task ${status === 'completed' ? 'completed' : status === 'failed' ? 'failed' : 'running'}`,
          taskType: data.task_type,
          status: status,
          result: data.result,
          timestamp: new Date(),
        });
        break;

      case 'error':
        addSystemMessage(`Error: ${data.message}`, 'system');
        break;
    }
  };

  const addSystemMessage = (content: string, source: string) => {
    addMessage({
      id: `sys_${Date.now()}`,
      type: 'system',
      source,
      content,
      timestamp: new Date(),
    });
  };

  const addMessage = (message: Message) => {
    setMessages(prev => [...prev, message]);
    // Persist to SQLite via API (fire and forget)
    storageApi.logEvent({
      id: message.id,
      type: message.type,
      source: message.source,
      content: message.content,
      taskType: message.taskType,
      status: message.status,
      result: message.result,
      timestamp: message.timestamp.getTime(),
    });
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text).then(() => {
      const notification = document.createElement('div');
      notification.className = 'copy-notification';
      notification.textContent = `Copied ${label}`;
      document.body.appendChild(notification);
      setTimeout(() => notification.remove(), 2000);
    }).catch(err => {
      console.error('Failed to copy:', err);
    });
  };

  const updateDeviceActivity = (deviceId: string) => {
    setDevices(prev => {
      const existing = prev.find(d => d.id === deviceId);
      if (existing) {
        return prev.map(d => d.id === deviceId ? { ...d, lastSeen: new Date() } : d);
      } else {
        const isWebDashboard = deviceId === 'web_dashboard' || deviceId.includes('web_') || deviceId.includes('dashboard');
        const newDevice: DeviceInfo = {
          id: deviceId,
          type: isWebDashboard ? 'web' : 'ios',
          angle: Math.random() * 360,
          distance: 60 + Math.random() * 30,
          lastSeen: new Date(),
        };
        return [...prev, newDevice];
      }
    });
  };

  const calculateTaskRate = () => {
    const now = new Date();
    const oneMinuteAgo = new Date(now.getTime() - 60000);
    const recentTasks = messages.filter(m =>
      m.type === 'task_submit' && m.timestamp > oneMinuteAgo
    );
    return recentTasks.length;
  };

  const calculateSuccessRate = () => {
    const completedTasks = messages.filter(m => m.type === 'task_update' && m.status === 'completed');
    const failedTasks = messages.filter(m => m.type === 'task_update' && m.status === 'failed');
    const total = completedTasks.length + failedTasks.length;
    return total > 0 ? Math.round((completedTasks.length / total) * 100) : 100;
  };

  useEffect(() => {
    const canvas = radarCanvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    const maxRadius = 140;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = 'rgba(108, 92, 231, 0.25)';
    ctx.lineWidth = 1;
    for (let r = 30; r <= maxRadius; r += 30) {
      ctx.beginPath();
      ctx.arc(centerX, centerY, r, 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.strokeStyle = 'rgba(108, 92, 231, 0.15)';
    for (let i = 0; i < 8; i++) {
      const angle = (Math.PI * 2 * i) / 8;
      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      ctx.lineTo(
        centerX + Math.cos(angle) * maxRadius,
        centerY + Math.sin(angle) * maxRadius
      );
      ctx.stroke();
    }

    devices.forEach(device => {
      const angle = (device.angle * Math.PI) / 180;
      const distance = (device.distance / 100) * maxRadius;
      const x = centerX + Math.cos(angle) * distance;
      const y = centerY + Math.sin(angle) * distance;

      ctx.fillStyle = device.type === 'ios' ? '#22C55E' : '#6C5CE7';
      ctx.beginPath();
      ctx.arc(x, y, 6, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = device.type === 'ios' ? 'rgba(34, 197, 94, 0.3)' : 'rgba(108, 92, 231, 0.3)';
      ctx.beginPath();
      ctx.arc(x, y, 12, 0, Math.PI * 2);
      ctx.fill();
    });

    const scanAngle = (Date.now() / 20) % 360;
    const gradient = ctx.createLinearGradient(
      centerX, centerY,
      centerX + Math.cos(scanAngle * Math.PI / 180) * maxRadius,
      centerY + Math.sin(scanAngle * Math.PI / 180) * maxRadius
    );
    gradient.addColorStop(0, 'rgba(108, 92, 231, 0.4)');
    gradient.addColorStop(1, 'rgba(108, 92, 231, 0)');

    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.moveTo(centerX, centerY);
    ctx.arc(centerX, centerY, maxRadius, scanAngle * Math.PI / 180, (scanAngle + 45) * Math.PI / 180);
    ctx.lineTo(centerX, centerY);
    ctx.fill();
  }, [devices]);

  useEffect(() => {
    const interval = setInterval(() => {
      const canvas = radarCanvasRef.current;
      if (canvas) {
        setDevices(d => [...d]);
      }
    }, 50);
    return () => clearInterval(interval);
  }, []);

  if (!status && !error) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner"></div>
        <p>Loading OpenCLI Dashboard...</p>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="quantum-header">
        <div className="header-title">
          <div className="title-main">System Status</div>
          <div className="title-sub">Real-time Monitoring v{status?.daemon.version || '0.1.0'}</div>
        </div>

        <div className="header-metrics">
          <div className="metric-item">
            <span className="metric-label">Uptime</span>
            <span className="metric-value">{status ? status.daemon.uptime_seconds : 0}s</span>
          </div>
          <div className="metric-item">
            <span className="metric-label">Health</span>
            <span className="metric-value">{calculateSuccessRate()}%</span>
          </div>
          <div className="metric-item">
            <span className="metric-label">Time</span>
            <span className="metric-value">
              {new Date().toLocaleTimeString('en-US', { hour12: false })}
            </span>
          </div>
          <div className="metric-item">
            <span className="metric-label">Status</span>
            <span className={`metric-value ${connected && wsConnected ? 'status-online' : 'status-offline'}`}>
              {connected && wsConnected ? 'ONLINE' : 'OFFLINE'}
            </span>
          </div>
        </div>
      </header>

      <div className="quantum-container">
        <div className="left-column">
          <div className="radar-section">
            <div className="section-header">
              <span className="header-label">Connected Devices</span>
              <span className="status-indicator">
                <span className="status-dot-live"></span>
                Live
              </span>
            </div>
            <div className="radar-container">
              <canvas
                ref={radarCanvasRef}
                width="300"
                height="300"
                className="radar-canvas"
              ></canvas>
              <div className="radar-overlay">
                <div className="radar-center-dot"></div>
              </div>
            </div>
            <div className="device-list">
              {devices.map(device => (
                <div key={device.id} className="device-item">
                  <span className="device-icon">{device.type === 'ios' ? '📱' : '💻'}</span>
                  <span className="device-id">{device.id.substring(0, 8)}...</span>
                </div>
              ))}
              {devices.length === 0 && (
                <div className="device-empty">No active devices</div>
              )}
            </div>
          </div>

          <div className="metrics-grid">
            <div className="metric-card">
              <div className="metric-label">iOS Clients</div>
              <div className="metric-value">{devices.filter(d => d.type === 'ios').length}</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">Web Clients</div>
              <div className="metric-value">{devices.filter(d => d.type === 'web').length}</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">Tasks/min</div>
              <div className="metric-value">{calculateTaskRate()}</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">Memory</div>
              <div className="metric-value">{status?.daemon.memory_mb.toFixed(0) || 0}MB</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">Plugins</div>
              <div className="metric-value">{status?.daemon.plugins_loaded || 0}</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">Success Rate</div>
              <div className="metric-value">{calculateSuccessRate()}%</div>
            </div>
          </div>

          <div className="signal-section">
            <div className="signal-bars">
              {[1, 2, 3, 4, 5].map(i => (
                <div
                  key={i}
                  className={`signal-bar ${connected && wsConnected && i <= 4 ? 'active' : ''}`}
                  style={{ height: `${i * 20}%` }}
                ></div>
              ))}
            </div>
            <div className="signal-label">
              Signal: {connected && wsConnected ? '87%' : '0%'}
            </div>
          </div>
        </div>

        <div className="right-column">
          <div className="status-tags">
            <div className="status-tag">
              <span className="tag-dot"></span>
              Connection Active
            </div>
            <div className="status-tag">
              Last update: {new Date().toLocaleTimeString('en-US', { hour12: true })}
            </div>
          </div>

          <div className="terminal-section">
            <div className="terminal-header">
              <span className="terminal-label">Event Log</span>
              <div className="terminal-controls">
                <span className="terminal-dot red"></span>
                <span className="terminal-dot yellow"></span>
                <span className="terminal-dot green"></span>
              </div>
            </div>
            <div className="terminal-content">
              <div ref={messagesTopRef} />
              {messages.length === 0 ? (
                <div className="terminal-line">
                  <span className="terminal-cursor">&gt;</span>
                  <span className="terminal-text">Waiting for events...</span>
                </div>
              ) : (
                [...messages].reverse().slice(0, 15).map((msg, idx) => (
                  <div key={msg.id} className="terminal-line" style={{ animationDelay: `${idx * 0.05}s` }}>
                    <span className="terminal-cursor">&gt;</span>
                    <span className="terminal-time">[{formatTime(msg.timestamp)}]</span>
                    <span className="terminal-source">{msg.source}:</span>
                    <span className="terminal-text">{msg.content}</span>
                    {msg.taskData && (
                      <button
                        className="terminal-copy-btn"
                        onClick={() => copyToClipboard(JSON.stringify(msg.taskData, null, 2), 'task data')}
                        title="Copy task data"
                      >
                        📋
                      </button>
                    )}
                    {msg.result && (
                      <button
                        className="terminal-copy-btn"
                        onClick={() => copyToClipboard(JSON.stringify(msg.result, null, 2), 'result')}
                        title="Copy result"
                      >
                        📋
                      </button>
                    )}
                  </div>
                ))
              )}
            </div>
          </div>

          <div className="action-buttons">
            <button className="quantum-button" onClick={() => {
              if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
                wsRef.current.send(JSON.stringify({
                  type: 'submit_task',
                  task_type: 'system_info',
                  task_data: { _user_input: 'system info' },
                }));
                addSystemMessage('Test task sent: system_info', 'user');
              } else {
                addSystemMessage('WebSocket not connected', 'system');
              }
            }}>
              <span className="button-icon material-symbols-outlined" style={{fontSize: '18px'}}>send</span>
              <span className="button-text">Send Test</span>
            </button>
            <button className="quantum-button secondary" onClick={() => {
              loadStatus();
              addSystemMessage('Status reloaded', 'user');
            }}>
              <span className="button-icon material-symbols-outlined" style={{fontSize: '18px'}}>refresh</span>
              <span className="button-text">Reload</span>
            </button>
          </div>
        </div>
      </div>

      <footer className="footer">
        <div className="footer-content">
          <span>OpenCLI Enterprise OS</span>
          <span className="footer-divider">|</span>
          <span>Last update: {status?.timestamp ? new Date(status.timestamp).toLocaleTimeString() : '--'}</span>
          <span className="footer-divider">|</span>
          <span className="footer-highlight">
            {messages.length} messages monitored
          </span>
        </div>
      </footer>
    </div>
  );
}

export default StatusPage;
