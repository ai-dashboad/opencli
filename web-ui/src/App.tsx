import { useState, useEffect, useRef } from 'react';
import { Routes, Route, Link, useLocation } from 'react-router-dom';
import PipelineEditor from './pages/PipelineEditor';
import './App.css';

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
  source: string; // 'ios', 'web', 'daemon'
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

function App() {
  const [status, setStatus] = useState<DaemonStatus | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [connected, setConnected] = useState(false);
  const [wsConnected, setWsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [devices, setDevices] = useState<DeviceInfo[]>([]);
  const messagesTopRef = useRef<HTMLDivElement>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const radarCanvasRef = useRef<HTMLCanvasElement>(null);

  // 滚动到顶部（最新消息）
  const scrollToTop = () => {
    messagesTopRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToTop();
  }, [messages]);

  // 加载状态
  useEffect(() => {
    loadStatus();
    const interval = setInterval(loadStatus, 3000);
    return () => clearInterval(interval);
  }, []);

  // WebSocket 连接
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
        addSystemMessage('已连接到 OpenCLI Daemon', 'system');

        // 发送认证
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
        addSystemMessage('与 Daemon 断开连接', 'system');

        // 5秒后重连
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
    // 使用 SHA256 生成认证 token（与 daemon 一致）
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
        addSystemMessage('认证成功，开始监听消息...', 'system');
        // 添加 Web UI 自己作为设备
        updateDeviceActivity('web_dashboard');
        break;

      case 'task_submitted':
        // 更新设备列表
        updateDeviceActivity(data.device_id);

        // 优先显示用户原始输入，如果没有则显示任务类型
        const userInput = data.task_data?._user_input;
        const displayContent = userInput
          ? `💬 ${userInput}`
          : `提交任务: ${data.task_type}`;

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
          content: `${emoji} 任务${status === 'completed' ? '完成' : status === 'failed' ? '失败' : '运行中'}`,
          taskType: data.task_type,
          status: status,
          result: data.result,
          timestamp: new Date(),
        });
        break;

      case 'error':
        addSystemMessage(`错误: ${data.message}`, 'system');
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
  };

  const formatUptime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hours}h ${minutes}m ${secs}s`;
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const getMessageIcon = (msg: Message) => {
    if (msg.type === 'system') return '🔔';
    if (msg.type === 'task_submit') return '📤';
    if (msg.type === 'task_update') {
      if (msg.status === 'completed') return '✅';
      if (msg.status === 'failed') return '❌';
      return '⏳';
    }
    return '💬';
  };

  const getSourceLabel = (source: string) => {
    if (source.includes('ios')) return '📱 iOS';
    if (source === 'web_dashboard') return '💻 Web';
    if (source === 'daemon') return '🤖 Daemon';
    if (source === 'system') return '⚙️ System';
    return source;
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text).then(() => {
      // Show a brief success indication
      const notification = document.createElement('div');
      notification.className = 'copy-notification';
      notification.textContent = `✓ ${label} 已复制`;
      document.body.appendChild(notification);
      setTimeout(() => notification.remove(), 2000);
    }).catch(err => {
      console.error('Failed to copy:', err);
    });
  };

  // 更新设备活动状态
  const updateDeviceActivity = (deviceId: string) => {
    setDevices(prev => {
      const existing = prev.find(d => d.id === deviceId);
      if (existing) {
        return prev.map(d => d.id === deviceId ? { ...d, lastSeen: new Date() } : d);
      } else {
        // 新设备，随机分配角度和距离
        // 检测设备类型：web_dashboard 是 web，其他都是 iOS/移动设备
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

  // 计算任务速率（任务/分钟）
  const calculateTaskRate = () => {
    const now = new Date();
    const oneMinuteAgo = new Date(now.getTime() - 60000);
    const recentTasks = messages.filter(m =>
      m.type === 'task_submit' && m.timestamp > oneMinuteAgo
    );
    return recentTasks.length;
  };

  // 计算成功率
  const calculateSuccessRate = () => {
    const completedTasks = messages.filter(m => m.type === 'task_update' && m.status === 'completed');
    const failedTasks = messages.filter(m => m.type === 'task_update' && m.status === 'failed');
    const total = completedTasks.length + failedTasks.length;
    return total > 0 ? Math.round((completedTasks.length / total) * 100) : 100;
  };

  // 绘制雷达可视化
  useEffect(() => {
    const canvas = radarCanvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    const maxRadius = 140;

    // 清空画布
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // 绘制网格圆圈
    ctx.strokeStyle = 'rgba(0, 240, 255, 0.2)';
    ctx.lineWidth = 1;
    for (let r = 30; r <= maxRadius; r += 30) {
      ctx.beginPath();
      ctx.arc(centerX, centerY, r, 0, Math.PI * 2);
      ctx.stroke();
    }

    // 绘制网格线
    ctx.strokeStyle = 'rgba(0, 240, 255, 0.15)';
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

    // 绘制设备点
    devices.forEach(device => {
      const angle = (device.angle * Math.PI) / 180;
      const distance = (device.distance / 100) * maxRadius;
      const x = centerX + Math.cos(angle) * distance;
      const y = centerY + Math.sin(angle) * distance;

      // 设备点
      ctx.fillStyle = device.type === 'ios' ? '#ff006e' : '#00f0ff';
      ctx.beginPath();
      ctx.arc(x, y, 6, 0, Math.PI * 2);
      ctx.fill();

      // 发光效果
      ctx.fillStyle = device.type === 'ios' ? 'rgba(255, 0, 110, 0.3)' : 'rgba(0, 240, 255, 0.3)';
      ctx.beginPath();
      ctx.arc(x, y, 12, 0, Math.PI * 2);
      ctx.fill();
    });

    // 扫描线动画
    const scanAngle = (Date.now() / 20) % 360;
    const gradient = ctx.createLinearGradient(
      centerX, centerY,
      centerX + Math.cos(scanAngle * Math.PI / 180) * maxRadius,
      centerY + Math.sin(scanAngle * Math.PI / 180) * maxRadius
    );
    gradient.addColorStop(0, 'rgba(0, 240, 255, 0.5)');
    gradient.addColorStop(1, 'rgba(0, 240, 255, 0)');

    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.moveTo(centerX, centerY);
    ctx.arc(centerX, centerY, maxRadius, scanAngle * Math.PI / 180, (scanAngle + 45) * Math.PI / 180);
    ctx.lineTo(centerX, centerY);
    ctx.fill();
  }, [devices]);

  // 雷达动画循环
  useEffect(() => {
    const interval = setInterval(() => {
      const canvas = radarCanvasRef.current;
      if (canvas) {
        // 触发重绘
        setDevices(d => [...d]);
      }
    }, 50);
    return () => clearInterval(interval);
  }, []);

  const location = useLocation();

  // Pipeline editor has its own layout
  if (location.pathname.startsWith('/pipelines')) {
    return (
      <Routes>
        <Route path="/pipelines" element={<PipelineEditor />} />
        <Route path="/pipelines/:id" element={<PipelineEditor />} />
      </Routes>
    );
  }

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
      {/* 背景效果 */}
      <div className="bg-gradient"></div>
      <div className="bg-grid"></div>
      <div className="bg-stars"></div>

      {/* 【组件1】顶部状态栏 - 科幻风格 */}
      <header className="quantum-header">
        <div className="header-title">
          <div className="title-main">OPENCLI_PORTAL</div>
          <div className="title-sub">REALTIME_MONITORING_SYSTEM v{status?.daemon.version || '0.1.0'}</div>
        </div>

        <Link to="/pipelines" className="pipeline-nav-link">PIPELINE_EDITOR</Link>

        <div className="header-metrics">
          <div className="metric-item">
            <span className="metric-label">UPTIME:</span>
            <span className="metric-value">{status ? status.daemon.uptime_seconds : 0}s</span>
          </div>
          <div className="metric-item">
            <span className="metric-label">FLUX:</span>
            <span className="metric-value">{calculateSuccessRate()}%</span>
          </div>
          <div className="metric-item">
            <span className="metric-label">SYS_TIME:</span>
            <span className="metric-value">
              {new Date().toLocaleTimeString('en-US', { hour12: false })}
            </span>
          </div>
          <div className="metric-item">
            <span className="metric-label">STATUS:</span>
            <span className={`metric-value ${connected && wsConnected ? 'status-online' : 'status-offline'}`}>
              {connected && wsConnected ? 'ONLINE' : 'OFFLINE'}
            </span>
          </div>
        </div>
      </header>

      {/* 主内容区 - 科幻布局 */}
      <div className="quantum-container">
        {/* 左侧列 */}
        <div className="left-column">
          {/* 【组件2】设备雷达可视化 */}
          <div className="radar-section">
            <div className="section-header">
              <span className="header-label">DEVICE_SCANNER.sys</span>
              <span className="status-indicator">
                <span className="status-dot-live"></span>
                LIVE_FEED
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

          {/* 【组件3】关键指标卡片网格 */}
          <div className="metrics-grid">
            <div className="metric-card">
              <div className="metric-label">iOS_CLIENTS</div>
              <div className="metric-value">{devices.filter(d => d.type === 'ios').length}</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">WEB_CLIENTS</div>
              <div className="metric-value">{devices.filter(d => d.type === 'web').length}</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">TASKS/MIN</div>
              <div className="metric-value">{calculateTaskRate()}</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">MEMORY</div>
              <div className="metric-value">{status?.daemon.memory_mb.toFixed(0) || 0}MB</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">PLUGINS</div>
              <div className="metric-value">{status?.daemon.plugins_loaded || 0}</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">SUCCESS_RATE</div>
              <div className="metric-value">{calculateSuccessRate()}%</div>
            </div>
          </div>

          {/* 【组件7】信号强度指示器 */}
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
              SIGNAL: {connected && wsConnected ? '87%' : '0%'}
            </div>
          </div>
        </div>

        {/* 右侧列 */}
        <div className="right-column">
          {/* 【组件9】状态标签 */}
          <div className="status-tags">
            <div className="status-tag">
              <span className="tag-dot"></span>
              QUANTUM_LINK_ACTIVE
            </div>
            <div className="status-tag">
              LAST_UPDATE: {new Date().toLocaleTimeString('en-US', { hour12: true })}
            </div>
          </div>

          {/* 【组件4】终端风格日志流 */}
          <div className="terminal-section">
            <div className="terminal-header">
              <span className="terminal-label">DATA_STREAM:</span>
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
                  <span className="terminal-text">AWAITING_TRANSMISSION...</span>
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
                        onClick={() => copyToClipboard(JSON.stringify(msg.taskData, null, 2), '任务数据')}
                        title="复制任务数据"
                      >
                        📋
                      </button>
                    )}
                    {msg.result && (
                      <button
                        className="terminal-copy-btn"
                        onClick={() => copyToClipboard(JSON.stringify(msg.result, null, 2), 'LLM 响应')}
                        title="复制 LLM 响应"
                      >
                        📋
                      </button>
                    )}
                  </div>
                ))
              )}
            </div>
          </div>

          {/* 【组件8】大按钮组件 */}
          <div className="action-buttons">
            <button className="quantum-button">
              <span className="button-icon">🌀</span>
              <span className="button-text">QUANTUM_TRANSPORT.exe</span>
            </button>
            <button className="quantum-button secondary">
              <span className="button-icon">🔄</span>
              <span className="button-text">RELOAD_MATRIX.sys</span>
            </button>
          </div>
        </div>
      </div>

      {/* 底部保留 */}
      <div style={{ display: 'none' }}>
        <aside className="sidebar">
          <div className="stats-section">
            <h2 className="section-title">
              <span className="title-icon">📊</span>
              System Status
            </h2>

            {status && (
              <div className="stats-grid">
                <div className="stat-card">
                  <div className="stat-label">Version</div>
                  <div className="stat-value">{status.daemon.version}</div>
                </div>

                <div className="stat-card">
                  <div className="stat-label">Uptime</div>
                  <div className="stat-value">{formatUptime(status.daemon.uptime_seconds)}</div>
                </div>

                <div className="stat-card">
                  <div className="stat-label">Memory</div>
                  <div className="stat-value">{status.daemon.memory_mb.toFixed(1)} MB</div>
                  <div className="stat-progress">
                    <div
                      className="stat-progress-bar"
                      style={{ width: `${Math.min(100, (status.daemon.memory_mb / 500) * 100)}%` }}
                    ></div>
                  </div>
                </div>

                <div className="stat-card">
                  <div className="stat-label">Plugins</div>
                  <div className="stat-value">{status.daemon.plugins_loaded}</div>
                </div>

                <div className="stat-card">
                  <div className="stat-label">Requests</div>
                  <div className="stat-value">{status.daemon.total_requests}</div>
                </div>

                <div className="stat-card">
                  <div className="stat-label">Mobile Clients</div>
                  <div className="stat-value">{status.mobile.connected_clients}</div>
                </div>
              </div>
            )}
          </div>

          {error && (
            <div className="error-box">
              <span className="error-icon">⚠️</span>
              <div className="error-text">{error}</div>
            </div>
          )}
        </aside>

        {/* 右侧：消息流 */}
        <main className="main-content">
          <div className="messages-section">
            <h2 className="section-title">
              <span className="title-icon">💬</span>
              Real-time Messages
              <span className="message-count">{messages.length}</span>
            </h2>

            <div className="messages-container">
              {messages.length === 0 ? (
                <div className="empty-state">
                  <div className="empty-icon">📭</div>
                  <p>等待消息...</p>
                  <p className="empty-hint">来自 iOS、Web 或其他客户端的消息将在这里实时显示</p>
                </div>
              ) : (
                <div className="messages-list">
                  <div ref={messagesTopRef} />
                  {[...messages].reverse().map((msg) => (
                    <div key={msg.id} className={`message-item ${msg.type}`}>
                      <div className="message-header">
                        <span className="message-icon">{getMessageIcon(msg)}</span>
                        <span className="message-source">{getSourceLabel(msg.source)}</span>
                        <span className="message-time">{formatTime(msg.timestamp)}</span>
                      </div>

                      <div className="message-content">
                        {msg.content}
                        {msg.taskType && (
                          <span className="task-type-badge">{msg.taskType}</span>
                        )}
                      </div>

                      {msg.taskData && (
                        <div className="message-result">
                          <div className="result-header">
                            <div className="result-label">任务数据:</div>
                            <button
                              className="copy-btn"
                              onClick={() => copyToClipboard(JSON.stringify(msg.taskData, null, 2), '任务数据')}
                              title="复制任务数据"
                            >
                              📋 复制
                            </button>
                          </div>
                          <pre className="result-data">
                            {JSON.stringify(msg.taskData, null, 2)}
                          </pre>
                        </div>
                      )}

                      {msg.result && (
                        <div className="message-result">
                          <div className="result-header">
                            <div className="result-label">LLM 响应:</div>
                            <button
                              className="copy-btn"
                              onClick={() => copyToClipboard(JSON.stringify(msg.result, null, 2), 'LLM 响应')}
                              title="复制 LLM 响应"
                            >
                              📋 复制
                            </button>
                          </div>
                          <pre className="result-data">
                            {JSON.stringify(msg.result, null, 2)}
                          </pre>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </main>
      </div>

      {/* 底部状态栏 */}
      <footer className="footer">
        <div className="footer-content">
          <span>🤖 OpenCLI Enterprise OS</span>
          <span className="footer-divider">|</span>
          <span>Last update: {status?.timestamp ? new Date(status.timestamp).toLocaleTimeString('zh-CN') : '--'}</span>
          <span className="footer-divider">|</span>
          <span className="footer-highlight">
            {messages.length} messages monitored
          </span>
        </div>
      </footer>
    </div>
  );
}

export default App;
