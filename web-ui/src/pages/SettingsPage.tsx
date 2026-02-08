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
  link: string;
}

const AI_PROVIDERS: ProviderConfig[] = [
  {
    id: 'replicate',
    name: 'Replicate',
    configKey: 'replicate',
    placeholder: 'r8_xxxxxxxxxxxx',
    meta: 'Flux Schnell (image) + Kling v2.6 (video)',
    capabilities: ['Image', 'Video'],
    link: 'replicate.com/account/api-tokens',
  },
  {
    id: 'runway',
    name: 'Runway Gen-4',
    configKey: 'runway',
    placeholder: 'rwk_xxxxxxxxxxxx',
    meta: 'Gen-4 Turbo video generation',
    capabilities: ['Video'],
    link: 'app.runwayml.com/settings/api-keys',
  },
  {
    id: 'kling',
    name: 'Kling AI (PiAPI)',
    configKey: 'kling_piapi',
    placeholder: 'piapi_xxxxxxxxxxxx',
    meta: 'Kling v2.6 video via PiAPI proxy',
    capabilities: ['Video'],
    link: 'piapi.ai',
  },
  {
    id: 'luma',
    name: 'Luma Dream Machine',
    configKey: 'luma',
    placeholder: 'luma_xxxxxxxxxxxx',
    meta: 'Dream Machine video + Photon image',
    capabilities: ['Video', 'Image'],
    link: 'lumalabs.ai',
  },
  {
    id: 'stability',
    name: 'Stability AI',
    configKey: 'stability',
    placeholder: 'sk-xxxxxxxxxxxx',
    meta: 'Stable Diffusion XL, SD3, SDXL Turbo',
    capabilities: ['Image'],
    link: 'platform.stability.ai/account/keys',
  },
  {
    id: 'openai_image',
    name: 'DALL-E (OpenAI)',
    configKey: 'openai_dalle',
    placeholder: 'sk-xxxxxxxxxxxx',
    meta: 'DALL-E 3 image generation',
    capabilities: ['Image'],
    link: 'platform.openai.com/api-keys',
  },
  {
    id: 'minimax',
    name: 'Minimax / Hailuo',
    configKey: 'minimax',
    placeholder: 'mm_xxxxxxxxxxxx',
    meta: 'Hailuo AI video generation',
    capabilities: ['Video'],
    link: 'hailuoai.com',
  },
  {
    id: 'pika',
    name: 'Pika',
    configKey: 'pika',
    placeholder: 'pika_xxxxxxxxxxxx',
    meta: 'Pika 1.0 video generation',
    capabilities: ['Video'],
    link: 'pika.art',
  },
  {
    id: 'ideogram',
    name: 'Ideogram',
    configKey: 'ideogram',
    placeholder: 'ig_xxxxxxxxxxxx',
    meta: 'Ideogram 2.0 image + text rendering',
    capabilities: ['Image'],
    link: 'ideogram.ai',
  },
  {
    id: 'fal',
    name: 'fal.ai',
    configKey: 'fal',
    placeholder: 'fal_xxxxxxxxxxxx',
    meta: 'Fast Flux, SDXL, video models',
    capabilities: ['Image', 'Video'],
    link: 'fal.ai/dashboard',
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
  link: string;
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
    link: 'console.anthropic.com/settings/keys',
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
    link: 'platform.openai.com/api-keys',
  },
  {
    id: 'gemini',
    name: 'Gemini (Google)',
    icon: 'auto_awesome',
    configSection: 'gemini',
    keyField: 'api_key',
    placeholder: 'AIzaxxxxxxxxxxxx',
    modelName: 'gemini-2.0-flash',
    type: 'cloud',
    link: 'aistudio.google.com/apikey',
  },
  {
    id: 'deepseek',
    name: 'DeepSeek',
    icon: 'explore',
    configSection: 'deepseek',
    keyField: 'api_key',
    placeholder: 'sk-xxxxxxxxxxxx',
    modelName: 'deepseek-chat',
    type: 'cloud',
    link: 'platform.deepseek.com/api_keys',
  },
  {
    id: 'groq',
    name: 'Groq',
    icon: 'bolt',
    configSection: 'groq',
    keyField: 'api_key',
    placeholder: 'gsk_xxxxxxxxxxxx',
    modelName: 'llama-3.3-70b',
    type: 'cloud',
    link: 'console.groq.com/keys',
  },
  {
    id: 'mistral',
    name: 'Mistral',
    icon: 'air',
    configSection: 'mistral',
    keyField: 'api_key',
    placeholder: 'xxxxxxxxxxxx',
    modelName: 'mistral-large',
    type: 'cloud',
    link: 'console.mistral.ai/api-keys',
  },
  {
    id: 'perplexity',
    name: 'Perplexity',
    icon: 'travel_explore',
    configSection: 'perplexity',
    keyField: 'api_key',
    placeholder: 'pplx-xxxxxxxxxxxx',
    modelName: 'sonar-pro',
    type: 'cloud',
    link: 'perplexity.ai/settings/api',
  },
  {
    id: 'cohere',
    name: 'Cohere',
    icon: 'hub',
    configSection: 'cohere',
    keyField: 'api_key',
    placeholder: 'xxxxxxxxxxxx',
    modelName: 'command-r-plus',
    type: 'cloud',
    link: 'dashboard.cohere.com/api-keys',
  },
  {
    id: 'ollama',
    name: 'Ollama (Local)',
    icon: 'dns',
    configSection: 'ollama',
    keyField: 'base_url',
    placeholder: 'http://localhost:11434',
    modelName: 'llama3.2 / codellama / mistral',
    type: 'local',
    link: 'ollama.com',
  },
];

export default function SettingsPage() {
  const [tab, setTab] = useState<Tab>('generation');
  const [config, setConfig] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [banner, setBanner] = useState<{ type: 'success' | 'error' | 'info'; message: string } | null>(null);
  const [savingKey, setSavingKey] = useState<string | null>(null);

  // Editable API key values
  const [providerKeys, setProviderKeys] = useState<Record<string, string>>({});
  const [modelKeys, setModelKeys] = useState<Record<string, string>>({});

  const fetchConfig = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/config`);
      const data = await res.json();
      setConfig(data.config);

      const keys: Record<string, string> = {};
      AI_PROVIDERS.forEach((p) => {
        const val = data.config?.ai_video?.api_keys?.[p.configKey] ?? '';
        keys[p.id] = val.startsWith('****') ? '' : val;
      });
      setProviderKeys(keys);

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

  // Auto-dismiss banner
  useEffect(() => {
    if (!banner) return;
    const t = setTimeout(() => setBanner(null), 4000);
    return () => clearTimeout(t);
  }, [banner]);

  const isProviderConfigured = (provider: ProviderConfig) => {
    const val = config?.ai_video?.api_keys?.[provider.configKey];
    return val && val !== '' && val !== 'null';
  };

  const isModelConfigured = (model: ModelConfig) => {
    const val = config?.models?.[model.configSection]?.[model.keyField];
    return val && val !== '' && val !== 'null';
  };

  // Save a single provider key immediately
  const saveProviderKey = async (provider: ProviderConfig) => {
    const key = providerKeys[provider.id]?.trim();
    if (!key) return;
    setSavingKey(provider.id);
    try {
      const res = await fetch(`${API_BASE}/api/v1/config`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ai_video: { api_keys: { [provider.configKey]: key } } }),
      });
      const data = await res.json();
      if (data.success) {
        setBanner({ type: 'success', message: `${provider.name} key saved and activated.` });
        await fetchConfig();
      } else {
        setBanner({ type: 'error', message: data.error || 'Failed to save' });
      }
    } catch {
      setBanner({ type: 'error', message: 'Failed to save. Check daemon connection.' });
    } finally {
      setSavingKey(null);
    }
  };

  // Save a single model key immediately
  const saveModelKey = async (model: ModelConfig) => {
    const key = modelKeys[model.id]?.trim();
    if (!key) return;
    setSavingKey(model.id);
    try {
      const section = config?.models?.[model.configSection] ?? {};
      const res = await fetch(`${API_BASE}/api/v1/config`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          models: { [model.configSection]: { ...section, [model.keyField]: key } },
        }),
      });
      const data = await res.json();
      if (data.success) {
        setBanner({ type: 'success', message: `${model.name} configured and activated.` });
        await fetchConfig();
      } else {
        setBanner({ type: 'error', message: data.error || 'Failed to save' });
      }
    } catch {
      setBanner({ type: 'error', message: 'Failed to save. Check daemon connection.' });
    } finally {
      setSavingKey(null);
    }
  };

  // Handle Enter key to save
  const handleProviderKeyDown = (e: React.KeyboardEvent, provider: ProviderConfig) => {
    if (e.key === 'Enter') saveProviderKey(provider);
  };
  const handleModelKeyDown = (e: React.KeyboardEvent, model: ModelConfig) => {
    if (e.key === 'Enter') saveModelKey(model);
  };

  if (loading) {
    return (
      <div className="st-page">
        <div className="st-header"><h1>Settings</h1></div>
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
        <div className="st-section">
          <div className="st-section-header">
            <div className="st-section-icon purple">
              <span className="material-icons">movie</span>
            </div>
            <div>
              <div className="st-section-title">AI Video & Image Providers</div>
              <div className="st-section-desc">Enter an API key and press Enter or click Save — changes apply instantly</div>
            </div>
          </div>

          <div className="st-provider-list">
            {AI_PROVIDERS.map((p) => {
              const active = isProviderConfigured(p);
              const saving = savingKey === p.id;
              return (
                <div key={p.id} className={`st-provider${active ? ' configured' : ''}`}>
                  <div className="st-provider-top">
                    <div className="st-provider-info">
                      <span className="st-provider-name">{p.name}</span>
                      <span className={`st-provider-badge ${active ? 'active' : 'inactive'}`}>
                        {active ? 'ACTIVE' : 'NOT SET'}
                      </span>
                      {p.capabilities.map((c) => (
                        <span key={c} className="st-cap-badge">{c}</span>
                      ))}
                    </div>
                    <a className="st-provider-link" href={`https://${p.link}`} target="_blank" rel="noopener noreferrer">
                      Get Key
                    </a>
                  </div>
                  <div className="st-key-row">
                    <input
                      className="st-key-input"
                      type="password"
                      placeholder={active ? '••••••••' : p.placeholder}
                      value={providerKeys[p.id] || ''}
                      onChange={(e) => setProviderKeys((prev) => ({ ...prev, [p.id]: e.target.value }))}
                      onKeyDown={(e) => handleProviderKeyDown(e, p)}
                    />
                    <button
                      className="st-key-btn save"
                      disabled={!providerKeys[p.id]?.trim() || saving}
                      onClick={() => saveProviderKey(p)}
                    >
                      {saving ? '...' : 'Save'}
                    </button>
                  </div>
                  <div className="st-provider-meta" style={{ marginTop: 6 }}>{p.meta}</div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* LLM Models Tab */}
      {tab === 'models' && (
        <div className="st-section">
          <div className="st-section-header">
            <div className="st-section-icon blue">
              <span className="material-icons">psychology</span>
            </div>
            <div>
              <div className="st-section-title">Language Models</div>
              <div className="st-section-desc">Configure AI assistants — Enter key and press Enter to save</div>
            </div>
          </div>

          <div className="st-model-list">
            {LLM_MODELS.map((m) => {
              const active = isModelConfigured(m);
              const saving = savingKey === m.id;
              return (
                <div key={m.id} className={`st-model${active ? ' configured' : ''}`}>
                  <div className="st-model-icon">
                    <span className="material-icons">{m.icon}</span>
                  </div>
                  <div className="st-model-body">
                    <div className="st-model-name">
                      {m.name}
                      <a className="st-model-link" href={`https://${m.link}`} target="_blank" rel="noopener noreferrer">
                        <span className="material-icons">open_in_new</span>
                      </a>
                    </div>
                    <div className="st-model-detail">{m.modelName}</div>
                  </div>
                  <div className="st-model-key">
                    <input
                      className="st-key-input"
                      type={m.type === 'local' ? 'text' : 'password'}
                      placeholder={active ? '••••••••' : m.placeholder}
                      value={modelKeys[m.id] || ''}
                      onChange={(e) => setModelKeys((prev) => ({ ...prev, [m.id]: e.target.value }))}
                      onKeyDown={(e) => handleModelKeyDown(e, m)}
                    />
                  </div>
                  <button
                    className="st-key-btn save"
                    disabled={!modelKeys[m.id]?.trim() || saving}
                    onClick={() => saveModelKey(m)}
                  >
                    {saving ? '...' : 'Save'}
                  </button>
                  <span className={`st-provider-badge ${active ? 'active' : 'inactive'}`}>
                    {active ? 'ACTIVE' : ''}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
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
                <div className="st-model-icon"><span className="material-icons">folder</span></div>
                <div className="st-model-body">
                  <div className="st-model-name">Config File</div>
                  <div className="st-model-detail">~/.opencli/config.yaml</div>
                </div>
              </div>
              <div className="st-model">
                <div className="st-model-icon"><span className="material-icons">lan</span></div>
                <div className="st-model-body">
                  <div className="st-model-name">Daemon Ports</div>
                  <div className="st-model-detail">API: 9529 | WS: 9876 | Status: 9875</div>
                </div>
              </div>
              <div className="st-model">
                <div className="st-model-icon"><span className="material-icons">security</span></div>
                <div className="st-model-body">
                  <div className="st-model-name">Socket Path</div>
                  <div className="st-model-detail">{config?.security?.socket_path ?? '/tmp/opencli.sock'}</div>
                </div>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
