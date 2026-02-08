import { useState, useEffect, useCallback } from 'react';
import '../styles/settings.css';

const API_BASE = 'http://localhost:9529';

type Tab = 'generation' | 'models' | 'general';

interface ProviderConfig {
  id: string;
  name: string;
  configKey: string;
  placeholder: string;
  meta: string;
  capabilities: string[];
}

const AI_PROVIDERS: ProviderConfig[] = [
  {
    id: 'replicate',
    name: 'Replicate',
    configKey: 'replicate',
    placeholder: 'r8_xxxxxxxxxxxx',
    meta: 'Flux Schnell (image) + Kling v2.6 (video) — ~$0.20-0.28/gen',
    capabilities: ['Image Generation', 'Video Generation'],
  },
  {
    id: 'runway',
    name: 'Runway Gen-4',
    configKey: 'runway',
    placeholder: 'rwk_xxxxxxxxxxxx',
    meta: 'Gen-4 Turbo video generation — ~$0.75/gen',
    capabilities: ['Video Generation'],
  },
  {
    id: 'kling',
    name: 'Kling AI (PiAPI)',
    configKey: 'kling_piapi',
    placeholder: 'piapi_xxxxxxxxxxxx',
    meta: 'Kling v2.6 video via PiAPI — ~$0.90/gen',
    capabilities: ['Video Generation'],
  },
  {
    id: 'luma',
    name: 'Luma Dream Machine',
    configKey: 'luma',
    placeholder: 'luma_xxxxxxxxxxxx',
    meta: 'Dream Machine video — ~$0.20/gen',
    capabilities: ['Video Generation'],
  },
];

interface ModelConfig {
  id: string;
  name: string;
  icon: string;
  configSection: string;
  keyField: string;
  placeholder: string;
  modelName: string;
  type: 'cloud' | 'local';
}

const LLM_MODELS: ModelConfig[] = [
  {
    id: 'claude',
    name: 'Claude (Anthropic)',
    icon: 'psychology',
    configSection: 'claude',
    keyField: 'api_key',
    placeholder: 'sk-ant-xxxxxxxxxxxx',
    modelName: 'claude-sonnet-4-20250514',
    type: 'cloud',
  },
  {
    id: 'gpt',
    name: 'GPT (OpenAI)',
    icon: 'smart_toy',
    configSection: 'gpt',
    keyField: 'api_key',
    placeholder: 'sk-xxxxxxxxxxxx',
    modelName: 'gpt-4-turbo',
    type: 'cloud',
  },
  {
    id: 'gemini',
    name: 'Gemini (Google)',
    icon: 'auto_awesome',
    configSection: 'gemini',
    keyField: 'api_key',
    placeholder: 'AIzaxxxxxxxxxxxx',
    modelName: 'gemini-2.0-flash-exp',
    type: 'cloud',
  },
  {
    id: 'ollama',
    name: 'Ollama (Local)',
    icon: 'dns',
    configSection: 'ollama',
    keyField: 'base_url',
    placeholder: 'http://localhost:11434',
    modelName: 'codellama',
    type: 'local',
  },
];

export default function SettingsPage() {
  const [tab, setTab] = useState<Tab>('generation');
  const [config, setConfig] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [banner, setBanner] = useState<{ type: 'success' | 'error' | 'info'; message: string } | null>(null);

  // Editable API key values
  const [providerKeys, setProviderKeys] = useState<Record<string, string>>({});
  const [modelKeys, setModelKeys] = useState<Record<string, string>>({});
  const [hasChanges, setHasChanges] = useState(false);

  const fetchConfig = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/config`);
      const data = await res.json();
      setConfig(data.config);

      // Init provider keys from config
      const keys: Record<string, string> = {};
      AI_PROVIDERS.forEach((p) => {
        const val = data.config?.ai_video?.api_keys?.[p.configKey] ?? '';
        keys[p.id] = val.startsWith('****') ? '' : val;
      });
      setProviderKeys(keys);

      // Init model keys from config
      const mkeys: Record<string, string> = {};
      LLM_MODELS.forEach((m) => {
        const val = data.config?.models?.[m.configSection]?.[m.keyField] ?? '';
        mkeys[m.id] = val.startsWith('****') ? '' : val;
      });
      setModelKeys(mkeys);
    } catch {
      setBanner({ type: 'error', message: 'Failed to connect to daemon. Is it running?' });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchConfig();
  }, [fetchConfig]);

  const isProviderConfigured = (provider: ProviderConfig) => {
    const val = config?.ai_video?.api_keys?.[provider.configKey];
    return val && val !== '' && val !== 'null';
  };

  const isModelConfigured = (model: ModelConfig) => {
    const val = config?.models?.[model.configSection]?.[model.keyField];
    return val && val !== '' && val !== 'null';
  };

  const handleProviderKeyChange = (id: string, value: string) => {
    setProviderKeys((prev) => ({ ...prev, [id]: value }));
    setHasChanges(true);
  };

  const handleModelKeyChange = (id: string, value: string) => {
    setModelKeys((prev) => ({ ...prev, [id]: value }));
    setHasChanges(true);
  };

  const handleSave = async () => {
    try {
      // Build update payload
      const updates: any = {};

      // Provider keys
      const apiKeys: any = {};
      let hasProviderUpdate = false;
      AI_PROVIDERS.forEach((p) => {
        if (providerKeys[p.id] && providerKeys[p.id].trim()) {
          apiKeys[p.configKey] = providerKeys[p.id].trim();
          hasProviderUpdate = true;
        }
      });
      if (hasProviderUpdate) {
        updates.ai_video = { api_keys: apiKeys };
      }

      // Model keys
      let hasModelUpdate = false;
      const models: any = {};
      LLM_MODELS.forEach((m) => {
        if (modelKeys[m.id] && modelKeys[m.id].trim()) {
          models[m.configSection] = {
            ...(config?.models?.[m.configSection] ?? {}),
            [m.keyField]: modelKeys[m.id].trim(),
          };
          hasModelUpdate = true;
        }
      });
      if (hasModelUpdate) {
        updates.models = models;
      }

      if (!hasProviderUpdate && !hasModelUpdate) {
        setBanner({ type: 'info', message: 'No changes to save.' });
        return;
      }

      const res = await fetch(`${API_BASE}/api/v1/config`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updates),
      });

      const data = await res.json();
      if (data.success) {
        setBanner({ type: 'success', message: 'Config saved! Restart the daemon to apply changes.' });
        setHasChanges(false);
        // Refresh config
        await fetchConfig();
      } else {
        setBanner({ type: 'error', message: data.error || 'Failed to save' });
      }
    } catch {
      setBanner({ type: 'error', message: 'Failed to save config. Check daemon connection.' });
    }
  };

  if (loading) {
    return (
      <div className="st-page">
        <div className="st-header">
          <h1>Settings</h1>
        </div>
        <div className="st-banner info">
          <span className="material-icons">hourglass_empty</span>
          Loading configuration...
        </div>
      </div>
    );
  }

  return (
    <div className="st-page">
      <div className="st-header">
        <h1>Settings</h1>
        <p className="st-header-sub">Configure AI providers, models, and preferences</p>
      </div>

      {banner && (
        <div className={`st-banner ${banner.type}`}>
          <span className="material-icons">
            {banner.type === 'success' ? 'check_circle' : banner.type === 'error' ? 'error' : 'info'}
          </span>
          {banner.message}
        </div>
      )}

      <div className="st-tabs">
        <button className={`st-tab${tab === 'generation' ? ' active' : ''}`} onClick={() => setTab('generation')}>
          <span className="material-icons">auto_awesome</span>
          AI Generation
        </button>
        <button className={`st-tab${tab === 'models' ? ' active' : ''}`} onClick={() => setTab('models')}>
          <span className="material-icons">psychology</span>
          LLM Models
        </button>
        <button className={`st-tab${tab === 'general' ? ' active' : ''}`} onClick={() => setTab('general')}>
          <span className="material-icons">tune</span>
          General
        </button>
      </div>

      {/* AI Generation Tab */}
      {tab === 'generation' && (
        <>
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon purple">
                <span className="material-icons">movie</span>
              </div>
              <div>
                <div className="st-section-title">AI Video & Image Providers</div>
                <div className="st-section-desc">API keys for cloud-based media generation</div>
              </div>
            </div>

            <div className="st-provider-list">
              {AI_PROVIDERS.map((p) => {
                const active = isProviderConfigured(p);
                return (
                  <div key={p.id} className={`st-provider${active ? ' configured' : ''}`}>
                    <div className="st-provider-top">
                      <div className="st-provider-info">
                        <span className="st-provider-name">{p.name}</span>
                        <span className={`st-provider-badge ${active ? 'active' : 'inactive'}`}>
                          {active ? 'ACTIVE' : 'NOT SET'}
                        </span>
                      </div>
                      <span className="st-provider-meta">
                        {p.capabilities.join(' + ')}
                      </span>
                    </div>
                    <div className="st-key-row">
                      <input
                        className="st-key-input"
                        type="password"
                        placeholder={p.placeholder}
                        value={providerKeys[p.id] || ''}
                        onChange={(e) => handleProviderKeyChange(p.id, e.target.value)}
                      />
                    </div>
                    <div className="st-provider-meta" style={{ marginTop: 6 }}>{p.meta}</div>
                  </div>
                );
              })}
            </div>
          </div>
        </>
      )}

      {/* LLM Models Tab */}
      {tab === 'models' && (
        <>
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon blue">
                <span className="material-icons">psychology</span>
              </div>
              <div>
                <div className="st-section-title">Language Models</div>
                <div className="st-section-desc">Configure AI assistants for task routing and chat</div>
              </div>
            </div>

            <div className="st-model-list">
              {LLM_MODELS.map((m) => {
                const active = isModelConfigured(m);
                return (
                  <div key={m.id} className={`st-model${active ? ' configured' : ''}`}>
                    <div className="st-model-icon">
                      <span className="material-icons">{m.icon}</span>
                    </div>
                    <div className="st-model-body">
                      <div className="st-model-name">{m.name}</div>
                      <div className="st-model-detail">
                        {m.modelName} {m.type === 'local' ? '(local)' : ''}
                      </div>
                    </div>
                    <div className="st-model-key">
                      <input
                        className="st-key-input"
                        type={m.type === 'local' ? 'text' : 'password'}
                        placeholder={m.placeholder}
                        value={modelKeys[m.id] || ''}
                        onChange={(e) => handleModelKeyChange(m.id, e.target.value)}
                      />
                    </div>
                    <span className={`st-provider-badge ${active ? 'active' : 'inactive'}`}>
                      {active ? 'ACTIVE' : 'NOT SET'}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </>
      )}

      {/* General Tab */}
      {tab === 'general' && (
        <>
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon green">
                <span className="material-icons">tune</span>
              </div>
              <div>
                <div className="st-section-title">General Settings</div>
                <div className="st-section-desc">Daemon behavior and preferences</div>
              </div>
            </div>

            <div className="st-toggle-row">
              <div>
                <div className="st-toggle-label">Auto Mode</div>
                <div className="st-toggle-desc">Automatically select best model for each task</div>
              </div>
              <label className="st-toggle">
                <input type="checkbox" checked={config?.auto_mode ?? true} readOnly />
                <span className="st-toggle-track" />
              </label>
            </div>

            <div className="st-toggle-row">
              <div>
                <div className="st-toggle-label">Cache</div>
                <div className="st-toggle-desc">Cache AI responses for faster repeat queries</div>
              </div>
              <label className="st-toggle">
                <input type="checkbox" checked={config?.cache?.enabled ?? true} readOnly />
                <span className="st-toggle-track" />
              </label>
            </div>

            <div className="st-toggle-row">
              <div>
                <div className="st-toggle-label">Plugin Auto-Load</div>
                <div className="st-toggle-desc">Automatically load plugins from ~/.opencli/plugins</div>
              </div>
              <label className="st-toggle">
                <input type="checkbox" checked={config?.plugins?.auto_load ?? true} readOnly />
                <span className="st-toggle-track" />
              </label>
            </div>
          </div>

          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon orange">
                <span className="material-icons">info</span>
              </div>
              <div>
                <div className="st-section-title">System Info</div>
                <div className="st-section-desc">Daemon and config details</div>
              </div>
            </div>

            <div className="st-model-list">
              <div className="st-model">
                <div className="st-model-icon">
                  <span className="material-icons">folder</span>
                </div>
                <div className="st-model-body">
                  <div className="st-model-name">Config File</div>
                  <div className="st-model-detail">~/.opencli/config.yaml</div>
                </div>
              </div>
              <div className="st-model">
                <div className="st-model-icon">
                  <span className="material-icons">lan</span>
                </div>
                <div className="st-model-body">
                  <div className="st-model-name">Daemon Ports</div>
                  <div className="st-model-detail">API: 9529 | WS: 9876 | Status: 9875</div>
                </div>
              </div>
              <div className="st-model">
                <div className="st-model-icon">
                  <span className="material-icons">security</span>
                </div>
                <div className="st-model-body">
                  <div className="st-model-name">Socket Path</div>
                  <div className="st-model-detail">{config?.security?.socket_path ?? '/tmp/opencli.sock'}</div>
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      {/* Sticky Save Bar */}
      {hasChanges && (
        <div className="st-save-bar">
          <span className="st-save-hint">You have unsaved changes</span>
          <button className="st-save-btn" onClick={handleSave}>
            Save Changes
          </button>
        </div>
      )}
    </div>
  );
}
