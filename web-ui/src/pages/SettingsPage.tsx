import { useState, useEffect, useCallback } from 'react';
import '../styles/settings.css';

const API_BASE = 'http://localhost:9529';

type Tab = 'generation' | 'models' | 'local' | 'colab' | 'general';

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
    id: 'pollinations',
    name: 'Pollinations.ai',
    configKey: 'pollinations',
    placeholder: 'pol_xxxxxxxxxxxx',
    meta: 'Seedance video (paid) + Flux image (free, no key needed)',
    capabilities: ['Video', 'Image'],
    link: 'pollinations.ai',
  },
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

interface LocalModel {
  id: string;
  name: string;
  type: string;
  capabilities: string[];
  size_gb: number;
  description: string;
  tags: string[];
  downloaded: boolean;
  disk_size_mb: number;
}

interface LocalEnv {
  ok: boolean;
  python_version: string;
  torch_version?: string;
  device: string;
  gpu?: string | null;
  missing_packages: string[];
  venv_exists: boolean;
}

export default function SettingsPage() {
  const [tab, setTab] = useState<Tab>('generation');
  const [config, setConfig] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [banner, setBanner] = useState<{ type: 'success' | 'error' | 'info'; message: string } | null>(null);
  const [savingKey, setSavingKey] = useState<string | null>(null);

  // Editable API key values
  const [providerKeys, setProviderKeys] = useState<Record<string, string>>({});
  const [modelKeys, setModelKeys] = useState<Record<string, string>>({});

  // Local models state
  const [localModels, setLocalModels] = useState<LocalModel[]>([]);
  const [localEnv, setLocalEnv] = useState<LocalEnv | null>(null);
  const [downloadingModel, setDownloadingModel] = useState<string | null>(null);
  const [settingUp, setSettingUp] = useState(false);

  // Colab GPU state
  const [colabStatus, setColabStatus] = useState<any>(null);
  const [colabUrl, setColabUrl] = useState('');
  const [colabBackend, setColabBackend] = useState('auto');
  const [testingColab, setTestingColab] = useState(false);
  const [savingColab, setSavingColab] = useState(false);

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

  const fetchLocalModels = useCallback(async () => {
    try {
      const [modelsRes, envRes] = await Promise.all([
        fetch(`${API_BASE}/api/v1/local-models`),
        fetch(`${API_BASE}/api/v1/local-models/environment`),
      ]);
      const modelsData = await modelsRes.json();
      const envData = await envRes.json();
      setLocalModels(modelsData.models || []);
      setLocalEnv(envData);
    } catch {
      // Local models API may not be available
    }
  }, []);

  const fetchColabStatus = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/inference/status`);
      const data = await res.json();
      setColabStatus(data);
      setColabUrl(data.colab_url || '');
      setColabBackend(data.backend || 'auto');
    } catch {
      // inference API may not be available
    }
  }, []);

  useEffect(() => {
    fetchConfig();
    fetchLocalModels();
    fetchColabStatus();
  }, [fetchConfig, fetchLocalModels, fetchColabStatus]);

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

  // Toggle a general setting
  const toggleSetting = async (path: string, currentValue: boolean) => {
    try {
      let body: Record<string, unknown>;
      if (path === 'auto_mode') {
        body = { auto_mode: !currentValue };
      } else if (path === 'cache.enabled') {
        body = { cache: { enabled: !currentValue } };
      } else if (path === 'plugins.auto_load') {
        body = { plugins: { auto_load: !currentValue } };
      } else return;
      const res = await fetch(`${API_BASE}/api/v1/config`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (data.success) {
        setBanner({ type: 'success', message: `Setting updated.` });
        await fetchConfig();
      } else {
        setBanner({ type: 'error', message: data.error || 'Failed to update' });
      }
    } catch {
      setBanner({ type: 'error', message: 'Failed to update. Check daemon connection.' });
    }
  };

  // Download a local model
  const downloadLocalModel = async (modelId: string) => {
    setDownloadingModel(modelId);
    setBanner({ type: 'info', message: `Downloading ${modelId}... This may take a while.` });
    try {
      const res = await fetch(`${API_BASE}/api/v1/local-models/${modelId}/download`, { method: 'POST' });
      const data = await res.json();
      if (data.success) {
        setBanner({ type: 'success', message: `${modelId} downloaded successfully!` });
        await fetchLocalModels();
      } else {
        setBanner({ type: 'error', message: data.error || 'Download failed' });
      }
    } catch {
      setBanner({ type: 'error', message: 'Download failed. Check daemon connection.' });
    } finally {
      setDownloadingModel(null);
    }
  };

  // Delete a local model
  const deleteLocalModel = async (modelId: string) => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/local-models/${modelId}`, { method: 'DELETE' });
      const data = await res.json();
      if (data.success) {
        setBanner({ type: 'success', message: `${modelId} deleted.` });
        await fetchLocalModels();
      } else {
        setBanner({ type: 'error', message: data.error || 'Delete failed' });
      }
    } catch {
      setBanner({ type: 'error', message: 'Delete failed.' });
    }
  };

  // Setup local inference environment
  const setupEnvironment = async () => {
    setSettingUp(true);
    setBanner({ type: 'info', message: 'Setting up Python environment... This may take a few minutes.' });
    try {
      const res = await fetch(`${API_BASE}/api/v1/local-models/setup`, { method: 'POST' });
      const data = await res.json();
      if (data.success) {
        setBanner({ type: 'success', message: 'Environment setup complete! Python + PyTorch ready.' });
        await fetchLocalModels();
      } else {
        setBanner({ type: 'error', message: data.message || data.error || 'Setup failed' });
      }
    } catch {
      setBanner({ type: 'error', message: 'Setup failed. Check daemon connection.' });
    } finally {
      setSettingUp(false);
    }
  };

  // Save Colab config
  const saveColabConfig = async () => {
    setSavingColab(true);
    try {
      const res = await fetch(`${API_BASE}/api/v1/config`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ inference: { backend: colabBackend, colab_url: colabUrl.trim() } }),
      });
      const data = await res.json();
      if (data.success) {
        setBanner({ type: 'success', message: 'Inference backend settings saved.' });
        await fetchColabStatus();
      } else {
        setBanner({ type: 'error', message: data.error || 'Failed to save' });
      }
    } catch {
      setBanner({ type: 'error', message: 'Failed to save. Check daemon connection.' });
    } finally {
      setSavingColab(false);
    }
  };

  // Test Colab connection
  const testColabConnection = async () => {
    setTestingColab(true);
    try {
      const urlToTest = colabUrl.trim() || colabStatus?.colab_url;
      if (!urlToTest) {
        setBanner({ type: 'error', message: 'Enter a Colab URL first.' });
        return;
      }
      const res = await fetch(`${API_BASE}/api/v1/inference/status`);
      const data = await res.json();
      if (data.colab_available) {
        const gpu = data.colab_info?.gpu || 'Unknown GPU';
        const vram = data.colab_info?.vram_total_gb || '?';
        setBanner({ type: 'success', message: `Connected! ${gpu} (${vram} GB VRAM)` });
      } else {
        setBanner({ type: 'error', message: 'Colab server not reachable. Is the notebook running?' });
      }
      setColabStatus(data);
    } catch {
      setBanner({ type: 'error', message: 'Failed to check. Is the daemon running?' });
    } finally {
      setTestingColab(false);
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
        <button className={`st-tab${tab === 'local' ? ' active' : ''}`} onClick={() => setTab('local')}>
          <span className="material-icons">computer</span>
          Local Models
        </button>
        <button className={`st-tab${tab === 'colab' ? ' active' : ''}`} onClick={() => setTab('colab')}>
          <span className="material-icons">cloud</span>
          Colab GPU
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

      {/* Local Models Tab */}
      {tab === 'local' && (
        <>
          {/* Environment Status */}
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon green">
                <span className="material-icons">memory</span>
              </div>
              <div>
                <div className="st-section-title">Local Environment</div>
                <div className="st-section-desc">Python + PyTorch inference runtime</div>
              </div>
            </div>

            {localEnv ? (
              <div className={`st-banner ${localEnv.ok ? 'success' : 'info'}`}>
                <span className="material-icons">{localEnv.ok ? 'check_circle' : 'info'}</span>
                <div>
                  <div>Python: {localEnv.python_version?.split(' ')[0] || 'not found'}</div>
                  {localEnv.torch_version && <div>PyTorch: {localEnv.torch_version}</div>}
                  <div>Device: {localEnv.device === 'mps' ? 'Apple Silicon (MPS)' : localEnv.device === 'cuda' ? `CUDA (${localEnv.gpu || 'GPU'})` : 'CPU'}</div>
                  {localEnv.missing_packages.length > 0 && (
                    <div style={{ marginTop: 4, color: 'var(--red)' }}>
                      Missing: {localEnv.missing_packages.join(', ')}
                    </div>
                  )}
                  {!localEnv.venv_exists && (
                    <div style={{ marginTop: 8 }}>
                      <button
                        className="st-key-btn save"
                        onClick={setupEnvironment}
                        disabled={settingUp}
                        style={{ marginTop: 4 }}
                      >
                        {settingUp ? 'Setting up...' : 'Setup Environment'}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ) : (
              <div className="st-banner info">
                <span className="material-icons">info</span>
                <div>
                  <div>Local inference environment not detected.</div>
                  <button
                    className="st-key-btn save"
                    onClick={setupEnvironment}
                    disabled={settingUp}
                    style={{ marginTop: 8 }}
                  >
                    {settingUp ? 'Setting up...' : 'Setup Environment'}
                  </button>
                </div>
              </div>
            )}
          </div>

          {/* Image Models */}
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon purple">
                <span className="material-icons">image</span>
              </div>
              <div>
                <div className="st-section-title">Image Generation</div>
                <div className="st-section-desc">Local text-to-image diffusion models — no API key required</div>
              </div>
            </div>

            <div className="st-provider-list">
              {(localModels.length > 0
                ? localModels.filter((m) => m.type === 'image' || m.type === 'text2img')
                : [
                    { id: 'waifu_diffusion', name: 'Waifu Diffusion', type: 'text2img', capabilities: ['image'], size_gb: 2.0, description: 'Anime-style image generation based on Stable Diffusion 1.5', tags: ['anime', 'illustration'], downloaded: false, disk_size_mb: 0 },
                    { id: 'animagine_xl', name: 'Animagine XL 3.1', type: 'text2img', capabilities: ['image'], size_gb: 6.5, description: 'High-quality anime image generation based on SDXL', tags: ['anime', 'illustration', 'xl'], downloaded: false, disk_size_mb: 0 },
                    { id: 'pony_diffusion', name: 'Pony Diffusion V6 XL', type: 'text2img', capabilities: ['image'], size_gb: 6.5, description: 'Versatile anime/illustration model based on SDXL', tags: ['anime', 'illustration', 'versatile', 'xl'], downloaded: false, disk_size_mb: 0 },
                  ]
              ).map((m) => (
                <div key={m.id} className={`st-provider${m.downloaded ? ' configured' : ''}`}>
                  <div className="st-provider-top">
                    <div className="st-provider-info">
                      <span className="st-provider-name">{m.name}</span>
                      <span className={`st-provider-badge ${m.downloaded ? 'active' : 'inactive'}`}>
                        {m.downloaded ? 'DOWNLOADED' : 'NOT INSTALLED'}
                      </span>
                      {(m.tags || []).map((t) => (
                        <span key={t} className="st-cap-badge">{t}</span>
                      ))}
                    </div>
                    <span className="st-provider-meta">{m.size_gb} GB</span>
                  </div>
                  <div className="st-provider-meta">{m.description}</div>
                  <div className="st-key-row" style={{ marginTop: 8 }}>
                    {m.downloaded ? (
                      <>
                        <span className="st-provider-meta" style={{ flex: 1 }}>
                          {(m.disk_size_mb || 0) > 0 ? `${(m.disk_size_mb || 0).toFixed(0)} MB on disk` : 'Installed'}
                        </span>
                        <button className="st-key-btn" onClick={() => deleteLocalModel(m.id)}>
                          Delete
                        </button>
                      </>
                    ) : (
                      <button
                        className="st-key-btn save"
                        disabled={downloadingModel !== null || !localEnv?.ok}
                        onClick={() => downloadLocalModel(m.id)}
                        style={{ width: '100%' }}
                      >
                        {downloadingModel === m.id ? 'Downloading...' : 'Download'}
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Video/Animation Models */}
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon blue">
                <span className="material-icons">movie</span>
              </div>
              <div>
                <div className="st-section-title">Video & Animation</div>
                <div className="st-section-desc">Local video generation and animation models</div>
              </div>
            </div>

            <div className="st-provider-list">
              {(localModels.length > 0
                ? localModels.filter((m) => m.type === 'video' || m.type === 'text2video' || m.type === 'img2video')
                : [
                    { id: 'animatediff', name: 'AnimateDiff', type: 'text2video', capabilities: ['video', 'animation'], size_gb: 4.5, description: 'Generate short animated videos from text prompts', tags: ['animation', 'video', 'motion'], downloaded: false, disk_size_mb: 0 },
                    { id: 'stable_video_diffusion', name: 'Stable Video Diffusion', type: 'img2video', capabilities: ['video'], size_gb: 4.0, description: 'Generate video from a single image', tags: ['video', 'img2vid'], downloaded: false, disk_size_mb: 0 },
                  ]
              ).map((m) => (
                <div key={m.id} className={`st-provider${m.downloaded ? ' configured' : ''}`}>
                  <div className="st-provider-top">
                    <div className="st-provider-info">
                      <span className="st-provider-name">{m.name}</span>
                      <span className={`st-provider-badge ${m.downloaded ? 'active' : 'inactive'}`}>
                        {m.downloaded ? 'DOWNLOADED' : 'NOT INSTALLED'}
                      </span>
                      {(m.tags || []).map((t) => (
                        <span key={t} className="st-cap-badge">{t}</span>
                      ))}
                    </div>
                    <span className="st-provider-meta">{m.size_gb} GB</span>
                  </div>
                  <div className="st-provider-meta">{m.description}</div>
                  <div className="st-key-row" style={{ marginTop: 8 }}>
                    {m.downloaded ? (
                      <>
                        <span className="st-provider-meta" style={{ flex: 1 }}>
                          {(m.disk_size_mb || 0) > 0 ? `${(m.disk_size_mb || 0).toFixed(0)} MB on disk` : 'Installed'}
                        </span>
                        <button className="st-key-btn" onClick={() => deleteLocalModel(m.id)}>
                          Delete
                        </button>
                      </>
                    ) : (
                      <button
                        className="st-key-btn save"
                        disabled={downloadingModel !== null || !localEnv?.ok}
                        onClick={() => downloadLocalModel(m.id)}
                        style={{ width: '100%' }}
                      >
                        {downloadingModel === m.id ? 'Downloading...' : 'Download'}
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Style Transfer */}
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon orange">
                <span className="material-icons">style</span>
              </div>
              <div>
                <div className="st-section-title">Style Transfer</div>
                <div className="st-section-desc">Transform photos into artistic styles</div>
              </div>
            </div>

            <div className="st-provider-list">
              {(localModels.length > 0
                ? localModels.filter((m) => m.type === 'style' || m.type === 'style_transfer')
                : [
                    { id: 'animegan_v3', name: 'AnimeGAN v3', type: 'style_transfer', capabilities: ['image', 'style_transfer'], size_gb: 0.1, description: 'Transform photos into anime-style artwork', tags: ['anime', 'style_transfer', 'lightweight'], downloaded: false, disk_size_mb: 0 },
                  ]
              ).map((m) => (
                <div key={m.id} className={`st-provider${m.downloaded ? ' configured' : ''}`}>
                  <div className="st-provider-top">
                    <div className="st-provider-info">
                      <span className="st-provider-name">{m.name}</span>
                      <span className={`st-provider-badge ${m.downloaded ? 'active' : 'inactive'}`}>
                        {m.downloaded ? 'DOWNLOADED' : 'NOT INSTALLED'}
                      </span>
                      {(m.tags || []).map((t) => (
                        <span key={t} className="st-cap-badge">{t}</span>
                      ))}
                    </div>
                    <span className="st-provider-meta">{m.size_gb} GB</span>
                  </div>
                  <div className="st-provider-meta">{m.description}</div>
                  <div className="st-key-row" style={{ marginTop: 8 }}>
                    {m.downloaded ? (
                      <>
                        <span className="st-provider-meta" style={{ flex: 1 }}>
                          {(m.disk_size_mb || 0) > 0 ? `${(m.disk_size_mb || 0).toFixed(0)} MB on disk` : 'Installed'}
                        </span>
                        <button className="st-key-btn" onClick={() => deleteLocalModel(m.id)}>
                          Delete
                        </button>
                      </>
                    ) : (
                      <button
                        className="st-key-btn save"
                        disabled={downloadingModel !== null || !localEnv?.ok}
                        onClick={() => downloadLocalModel(m.id)}
                        style={{ width: '100%' }}
                      >
                        {downloadingModel === m.id ? 'Downloading...' : 'Download'}
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </>
      )}

      {/* Colab GPU Tab */}
      {tab === 'colab' && (
        <>
          {/* Connection Status */}
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon purple">
                <span className="material-icons">cloud</span>
              </div>
              <div>
                <div className="st-section-title">Colab GPU Connection</div>
                <div className="st-section-desc">Connect to a Google Colab notebook for GPU-accelerated inference via FRP tunnel</div>
              </div>
            </div>

            <div className={`st-banner ${colabStatus?.colab_available ? 'success' : 'info'}`}>
              <span className="material-icons">
                {colabStatus?.colab_available ? 'check_circle' : 'cloud_off'}
              </span>
              <div style={{ flex: 1 }}>
                {colabStatus?.colab_available ? (
                  <>
                    <div><strong>Connected</strong> — {colabStatus.colab_info?.gpu || 'GPU'}</div>
                    <div style={{ fontSize: 11, marginTop: 2, color: 'var(--text-muted)' }}>
                      VRAM: {colabStatus.colab_info?.vram_total_gb || '?'} GB total,{' '}
                      {colabStatus.colab_info?.vram_used_gb || '0'} GB used
                      {colabStatus.colab_info?.models_loaded?.length > 0 &&
                        ` | Models: ${colabStatus.colab_info.models_loaded.join(', ')}`}
                    </div>
                  </>
                ) : (
                  <div>Not connected — start the Colab notebook to enable GPU inference</div>
                )}
              </div>
              <span className={`st-colab-dot ${colabStatus?.colab_available ? 'online' : 'offline'}`} />
            </div>
          </div>

          {/* Configuration */}
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon blue">
                <span className="material-icons">settings</span>
              </div>
              <div>
                <div className="st-section-title">Configuration</div>
                <div className="st-section-desc">Set the Colab server URL and inference routing mode</div>
              </div>
            </div>

            <div className="st-provider" style={{ marginBottom: 12 }}>
              <div className="st-provider-top">
                <div className="st-provider-info">
                  <span className="st-provider-name">Colab URL</span>
                  <span className="st-cap-badge">FRP</span>
                </div>
              </div>
              <div className="st-key-row">
                <input
                  className="st-key-input"
                  type="text"
                  placeholder="http://dtok.io:9530"
                  value={colabUrl}
                  onChange={(e) => setColabUrl(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter') saveColabConfig(); }}
                />
                <button
                  className="st-key-btn"
                  onClick={testColabConnection}
                  disabled={testingColab}
                >
                  {testingColab ? '...' : 'Test'}
                </button>
                <button
                  className="st-key-btn save"
                  onClick={saveColabConfig}
                  disabled={savingColab}
                >
                  {savingColab ? '...' : 'Save'}
                </button>
              </div>
              <div className="st-provider-meta" style={{ marginTop: 6 }}>
                Fixed FRP tunnel address — stays the same across Colab restarts
              </div>
            </div>

            {/* Backend selector */}
            <div className="st-provider">
              <div className="st-provider-top">
                <div className="st-provider-info">
                  <span className="st-provider-name">Inference Backend</span>
                </div>
              </div>
              <div className="st-colab-backend-row">
                {(['auto', 'colab', 'local'] as const).map((mode) => (
                  <button
                    key={mode}
                    className={`st-colab-backend-btn${colabBackend === mode ? ' active' : ''}`}
                    onClick={() => setColabBackend(mode)}
                  >
                    <span className="material-icons">
                      {mode === 'auto' ? 'auto_awesome' : mode === 'colab' ? 'cloud' : 'computer'}
                    </span>
                    <div>
                      <div className="st-colab-backend-label">
                        {mode === 'auto' ? 'Auto' : mode === 'colab' ? 'Colab Only' : 'Local Only'}
                      </div>
                      <div className="st-colab-backend-desc">
                        {mode === 'auto'
                          ? 'Use Colab if available, fall back to local'
                          : mode === 'colab'
                          ? 'Always use Colab (fails if offline)'
                          : 'Always use local MPS/CPU'}
                      </div>
                    </div>
                  </button>
                ))}
              </div>
              <div style={{ marginTop: 8, textAlign: 'right' }}>
                <button
                  className="st-key-btn save"
                  onClick={saveColabConfig}
                  disabled={savingColab}
                >
                  {savingColab ? 'Saving...' : 'Save Backend'}
                </button>
              </div>
            </div>
          </div>

          {/* How it works */}
          <div className="st-section">
            <div className="st-section-header">
              <div className="st-section-icon green">
                <span className="material-icons">help_outline</span>
              </div>
              <div>
                <div className="st-section-title">How It Works</div>
                <div className="st-section-desc">Architecture overview</div>
              </div>
            </div>

            <div className="st-colab-diagram">
              <div className="st-colab-node">
                <span className="material-icons">cloud</span>
                <div>Colab GPU</div>
                <div className="st-colab-node-sub">FastAPI + PyTorch</div>
              </div>
              <div className="st-colab-arrow">
                <span className="material-icons">arrow_forward</span>
                <div>FRP Tunnel</div>
              </div>
              <div className="st-colab-node">
                <span className="material-icons">dns</span>
                <div>NAS (dtok.io)</div>
                <div className="st-colab-node-sub">FRP Server :7000</div>
              </div>
              <div className="st-colab-arrow">
                <span className="material-icons">arrow_back</span>
                <div>HTTP</div>
              </div>
              <div className="st-colab-node">
                <span className="material-icons">computer</span>
                <div>Mac Daemon</div>
                <div className="st-colab-node-sub">Port 9529</div>
              </div>
            </div>

            <div className="st-model-list" style={{ marginTop: 12 }}>
              <div className="st-model">
                <div className="st-model-icon"><span className="material-icons">description</span></div>
                <div className="st-model-body">
                  <div className="st-model-name">Step 1: Open Colab Notebook</div>
                  <div className="st-model-detail">Open colab-inference/opencli_gpu.ipynb in Google Colab with GPU runtime</div>
                </div>
              </div>
              <div className="st-model">
                <div className="st-model-icon"><span className="material-icons">play_arrow</span></div>
                <div className="st-model-body">
                  <div className="st-model-name">Step 2: Run All Cells</div>
                  <div className="st-model-detail">Installs deps, mounts Drive, connects FRP, starts FastAPI server</div>
                </div>
              </div>
              <div className="st-model">
                <div className="st-model-icon"><span className="material-icons">check_circle</span></div>
                <div className="st-model-body">
                  <div className="st-model-name">Step 3: Verify Connection</div>
                  <div className="st-model-detail">Click "Test" above — should show GPU name and VRAM info</div>
                </div>
              </div>
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
                <input type="checkbox" checked={config?.auto_mode ?? true} onChange={() => toggleSetting('auto_mode', config?.auto_mode ?? true)} />
                <span className="st-toggle-track" />
              </label>
            </div>

            <div className="st-toggle-row">
              <div>
                <div className="st-toggle-label">Cache</div>
                <div className="st-toggle-desc">Cache AI responses for faster repeat queries</div>
              </div>
              <label className="st-toggle">
                <input type="checkbox" checked={config?.cache?.enabled ?? true} onChange={() => toggleSetting('cache.enabled', config?.cache?.enabled ?? true)} />
                <span className="st-toggle-track" />
              </label>
            </div>

            <div className="st-toggle-row">
              <div>
                <div className="st-toggle-label">Plugin Auto-Load</div>
                <div className="st-toggle-desc">Automatically load plugins from ~/.opencli/plugins</div>
              </div>
              <label className="st-toggle">
                <input type="checkbox" checked={config?.plugins?.auto_load ?? true} onChange={() => toggleSetting('plugins.auto_load', config?.plugins?.auto_load ?? true)} />
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
