import { useState, useEffect, useRef, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useDaemon } from '../hooks/useDaemon';
import { saveAsset } from '../utils/assetStorage';
import '../styles/create.css';

type Mode = 'img2vid' | 'txt2vid' | 'txt2img' | 'style';

interface Scenario {
  id: string;
  label: string;
  desc: string;
  icon: string;
  defaultMode: Mode;
  defaults: Partial<FormState>;
}

interface FormState {
  prompt: string;
  provider: string;
  style: string;
  duration: number;
  aspectRatio: string;
  negativePrompt: string;
  imageBase64: string | null;
  imagePreview: string | null;
  imageName: string | null;
}

const MODES: { id: Mode; label: string; icon: string; needsImage: boolean }[] = [
  { id: 'img2vid', label: 'Image to Video', icon: 'movie', needsImage: true },
  { id: 'txt2vid', label: 'Text to Video', icon: 'smart_display', needsImage: false },
  { id: 'txt2img', label: 'Text to Image', icon: 'image', needsImage: false },
  { id: 'style', label: 'Style Transfer', icon: 'style', needsImage: true },
];

const SCENARIOS: Scenario[] = [
  {
    id: 'product',
    label: 'Product Promo',
    desc: 'Professional ad-ready videos for products',
    icon: 'campaign',
    defaultMode: 'img2vid',
    defaults: { style: 'adPromo', aspectRatio: '16:9', duration: 10 },
  },
  {
    id: 'portrait',
    label: 'Portrait Effects',
    desc: 'Cinematic portrait transformations',
    icon: 'face_retouching_natural',
    defaultMode: 'img2vid',
    defaults: { style: 'cinematic', aspectRatio: '9:16', duration: 5 },
  },
  {
    id: 'story',
    label: 'Story to Video',
    desc: 'Turn text narratives into video',
    icon: 'auto_stories',
    defaultMode: 'txt2vid',
    defaults: { style: 'cinematic', aspectRatio: '16:9', duration: 10 },
  },
  {
    id: 'custom',
    label: 'Custom',
    desc: 'Full control over all settings',
    icon: 'tune',
    defaultMode: 'img2vid',
    defaults: {},
  },
];

const VIDEO_PROVIDERS = [
  { id: 'replicate', label: 'Replicate', sub: '~$0.28' },
  { id: 'runway', label: 'Runway Gen-4', sub: '~$0.75' },
  { id: 'kling', label: 'Kling AI', sub: '~$0.90' },
  { id: 'luma', label: 'Luma Dream', sub: '~$0.20' },
];

const IMAGE_PROVIDERS = [
  { id: 'pollinations', label: 'Pollinations', sub: 'FLUX (Free)' },
  { id: 'gemini', label: 'Google Gemini', sub: 'Imagen (Free)' },
  { id: 'replicate', label: 'Replicate', sub: 'Flux Schnell' },
  { id: 'luma', label: 'Luma', sub: 'Photon' },
];

const VIDEO_STYLES = [
  { id: 'cinematic', label: 'Cinematic', desc: 'Dramatic lighting, film grain', icon: 'movie' },
  { id: 'adPromo', label: 'Ad / Promo', desc: 'Commercial polish', icon: 'campaign' },
  { id: 'socialMedia', label: 'Social', desc: 'Scroll-stopping content', icon: 'share' },
  { id: 'calmAesthetic', label: 'Calm', desc: 'Soft, gentle movements', icon: 'spa' },
  { id: 'epic', label: 'Epic', desc: 'Grand dramatic sweeps', icon: 'landscape' },
  { id: 'mysterious', label: 'Mysterious', desc: 'Dark atmospheric mood', icon: 'visibility' },
];

const IMAGE_STYLES = [
  { id: 'photorealistic', label: 'Photorealistic', desc: 'Ultra-realistic photography', icon: 'photo_camera' },
  { id: 'digital_art', label: 'Digital Art', desc: 'Clean digital illustration', icon: 'palette' },
  { id: 'anime', label: 'Anime', desc: 'Japanese animation style', icon: 'animation' },
  { id: '3d_render', label: '3D Render', desc: 'Octane, Blender quality', icon: 'view_in_ar' },
  { id: 'watercolor', label: 'Watercolor', desc: 'Soft painterly strokes', icon: 'brush' },
  { id: 'pixel_art', label: 'Pixel Art', desc: 'Retro pixel aesthetic', icon: 'grid_on' },
];

const STYLE_PRESETS = [
  { id: 'face_paint_512_v2', label: 'Face Paint v2' },
  { id: 'celeba_distill', label: 'Celeba Distill' },
  { id: 'paprika', label: 'Paprika' },
];

const DURATIONS = [5, 10];
const ASPECT_RATIOS = ['16:9', '9:16', '1:1'];

// Step-based progress tracking
const PROGRESS_STEPS = [
  { id: 'submit', label: 'Submitting', threshold: 0 },
  { id: 'queue', label: 'Queued', threshold: 0.05 },
  { id: 'process', label: 'Processing', threshold: 0.15 },
  { id: 'download', label: 'Downloading', threshold: 0.85 },
  { id: 'complete', label: 'Complete', threshold: 1.0 },
];

// Average generation times by provider (seconds)
const PROVIDER_ETA: Record<string, number> = {
  pollinations: 15,
  gemini: 10,
  replicate: 30,
  runway: 90,
  kling: 120,
  luma: 45,
};

interface HistoryItem {
  id: string;
  mode: Mode;
  prompt: string;
  provider: string;
  style: string;
  resultType: 'video' | 'image';
  thumbnail?: string;
  timestamp: number;
}

function loadHistory(): HistoryItem[] {
  try {
    return JSON.parse(localStorage.getItem('opencli_gen_history') || '[]');
  } catch { return []; }
}

function saveHistory(items: HistoryItem[]) {
  localStorage.setItem('opencli_gen_history', JSON.stringify(items.slice(0, 20)));
}

const DEFAULT_FORM: FormState = {
  prompt: '',
  provider: 'pollinations',
  style: 'cinematic',
  duration: 5,
  aspectRatio: '16:9',
  negativePrompt: '',
  imageBase64: null,
  imagePreview: null,
  imageName: null,
};

export default function CreatePage() {
  const [searchParams] = useSearchParams();
  const { connected, authenticated, submitTask, subscribe, send } = useDaemon({ deviceId: 'web_create' });

  const [mode, setMode] = useState<Mode>('img2vid');
  const [scenario, setScenario] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>({ ...DEFAULT_FORM });
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Generation state
  const [generating, setGenerating] = useState(false);
  const [progress, setProgress] = useState(0);
  const [statusMessage, setStatusMessage] = useState('');
  const [resultUrl, setResultUrl] = useState<string | null>(null);
  const [resultType, setResultType] = useState<'video' | 'image'>('video');
  const [error, setError] = useState<string | null>(null);
  const [taskId, setTaskId] = useState<string | null>(null);
  const [startTime, setStartTime] = useState<number>(0);

  // Provider config & history
  const [configuredProviders, setConfiguredProviders] = useState<string[]>([]);
  const [history, setHistory] = useState<HistoryItem[]>(loadHistory);

  // Fetch configured providers from daemon
  useEffect(() => {
    fetch('http://localhost:9529/api/v1/config')
      .then(r => r.json())
      .then(data => {
        const keys = data?.ai_video?.api_keys || {};
        const configured = Object.entries(keys)
          .filter(([, v]) => v && typeof v === 'string' && !(v as string).startsWith('${'))
          .map(([k]) => k === 'kling_piapi' ? 'kling' : k);
        // Pollinations is always available (no API key needed)
        if (!configured.includes('pollinations')) configured.push('pollinations');
        // Check if Gemini has a key in models config
        const geminiKey = data?.models?.gemini?.api_key;
        if (geminiKey && typeof geminiKey === 'string' && !geminiKey.startsWith('${')) {
          if (!configured.includes('gemini')) configured.push('gemini');
        }
        setConfiguredProviders(configured);
        // Auto-select first configured provider
        if (configured.length > 0 && !configured.includes(form.provider)) {
          updateForm({ provider: configured[0] });
        }
      })
      .catch(() => {});
  }, []);

  // Initialize from URL params
  useEffect(() => {
    const urlPrompt = searchParams.get('prompt');
    if (urlPrompt) {
      setForm(f => ({ ...f, prompt: urlPrompt }));
    }
    const urlMode = searchParams.get('mode') as Mode | null;
    if (urlMode && MODES.find(m => m.id === urlMode)) {
      setMode(urlMode);
    }
  }, [searchParams]);

  const updateForm = (updates: Partial<FormState>) => {
    setForm(f => ({ ...f, ...updates }));
  };

  // Handle image file
  const handleImageFile = useCallback((file: File) => {
    if (!file.type.startsWith('image/')) return;
    setError(null);
    const reader = new FileReader();
    reader.onload = (e) => {
      const dataUrl = e.target?.result as string;
      updateForm({
        imagePreview: dataUrl,
        imageBase64: dataUrl.split(',')[1],
        imageName: file.name,
      });
    };
    reader.readAsDataURL(file);
  }, []);

  // Paste handler
  useEffect(() => {
    const handler = (e: ClipboardEvent) => {
      const file = e.clipboardData?.files[0];
      if (file && file.type.startsWith('image/')) {
        e.preventDefault();
        handleImageFile(file);
      }
    };
    document.addEventListener('paste', handler);
    return () => document.removeEventListener('paste', handler);
  }, [handleImageFile]);

  // WS message handler
  useEffect(() => {
    const unsub = subscribe((msg: any) => {
      if (msg.type !== 'task_update') return;
      const isVideo = msg.task_type === 'media_ai_generate_video';
      const isImage = msg.task_type === 'media_ai_generate_image';
      const isStyle = msg.task_type === 'media_local_style_transfer';
      if (!isVideo && !isImage && !isStyle) return;

      if (msg.status === 'running') {
        setProgress(msg.result?.progress ?? 0);
        setStatusMessage(msg.result?.status_message ?? 'Processing...');
      } else if (msg.status === 'completed') {
        setGenerating(false);
        setProgress(1);
        setStatusMessage('Complete!');
        setTaskId(null);

        const addHistoryItem = (rType: 'video' | 'image', thumb?: string) => {
          const item: HistoryItem = {
            id: `h_${Date.now()}`,
            mode,
            prompt: form.prompt.slice(0, 80),
            provider: form.provider,
            style: form.style,
            resultType: rType,
            thumbnail: thumb?.slice(0, 200),
            timestamp: Date.now(),
          };
          setHistory(prev => {
            const next = [item, ...prev].slice(0, 20);
            saveHistory(next);
            return next;
          });
        };

        if (isVideo && msg.result?.video_base64) {
          const binary = atob(msg.result.video_base64);
          const bytes = new Uint8Array(binary.length);
          for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
          const blob = new Blob([bytes], { type: 'video/mp4' });
          const blobUrl = URL.createObjectURL(blob);
          setResultUrl(blobUrl);
          setResultType('video');
          addHistoryItem('video');
          saveAsset({
            type: 'video',
            title: form.prompt.slice(0, 60) || 'Generated Video',
            url: blobUrl,
            provider: form.provider,
            style: form.style,
          });
        } else if ((isImage || isStyle) && (msg.result?.image_base64 || msg.result?.image_url)) {
          const imageUrl = msg.result?.image_base64
            ? `data:image/png;base64,${msg.result.image_base64}`
            : msg.result.image_url;
          setResultUrl(imageUrl);
          setResultType('image');
          addHistoryItem('image', imageUrl?.startsWith('data:') ? undefined : imageUrl);
          saveAsset({
            type: 'image',
            title: form.prompt.slice(0, 60) || 'Generated Image',
            url: imageUrl,
            thumbnail: imageUrl,
            provider: form.provider,
            style: form.style,
          });
        }
      } else if (msg.status === 'failed') {
        setGenerating(false);
        setTaskId(null);
        setError(msg.result?.message || msg.result?.error || 'Generation failed');
      } else if (msg.status === 'cancelled') {
        setGenerating(false);
        setTaskId(null);
        setStatusMessage('Cancelled');
      }
    });
    return unsub;
  }, [subscribe, form.prompt, form.provider, form.style]);

  // Cleanup blob URLs
  useEffect(() => {
    return () => {
      if (resultUrl && resultUrl.startsWith('blob:')) URL.revokeObjectURL(resultUrl);
    };
  }, [resultUrl]);

  const removeImage = () => {
    updateForm({ imageBase64: null, imagePreview: null, imageName: null });
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const handleGenerate = () => {
    if (generating) return;

    const currentMode = MODES.find(m => m.id === mode)!;
    if (currentMode.needsImage && !form.imageBase64) return;
    if (!currentMode.needsImage && !form.prompt.trim()) return;

    setGenerating(true);
    setProgress(0);
    setStatusMessage('Submitting...');
    setError(null);
    setStartTime(Date.now());
    if (resultUrl && resultUrl.startsWith('blob:')) URL.revokeObjectURL(resultUrl);
    setResultUrl(null);

    const id = `task_${Date.now()}`;
    setTaskId(id);

    switch (mode) {
      case 'img2vid':
        submitTask('media_ai_generate_video', {
          image_base64: form.imageBase64,
          style: form.style,
          provider: form.provider,
          ...(form.prompt ? { custom_prompt: form.prompt } : {}),
          ...(scenario ? { scenario } : {}),
          duration: form.duration,
          aspect_ratio: form.aspectRatio,
          _task_id: id,
        });
        setResultType('video');
        break;

      case 'txt2vid':
        submitTask('media_ai_generate_video', {
          style: form.style,
          provider: form.provider,
          custom_prompt: form.prompt,
          ...(scenario ? { scenario } : {}),
          duration: form.duration,
          aspect_ratio: form.aspectRatio,
          mode: 'production',
          input_text: form.prompt,
          _task_id: id,
        });
        setResultType('video');
        break;

      case 'txt2img':
        submitTask('media_ai_generate_image', {
          prompt: form.prompt.trim(),
          style: form.style,
          provider: form.provider,
          aspect_ratio: form.aspectRatio,
          ...(form.negativePrompt ? { negative_prompt: form.negativePrompt } : {}),
          ...(form.imageBase64 ? { reference_image_base64: form.imageBase64 } : {}),
          _task_id: id,
        });
        setResultType('image');
        break;

      case 'style':
        submitTask('media_local_style_transfer', {
          image_base64: form.imageBase64,
          style: form.style,
          _task_id: id,
        });
        setResultType('image');
        break;
    }
  };

  const handleCancel = () => {
    if (taskId) {
      send({ type: 'cancel_task', task_id: taskId });
      setGenerating(false);
      setTaskId(null);
      setStatusMessage('Cancelling...');
    }
  };

  const handleDownload = () => {
    if (!resultUrl) return;
    const a = document.createElement('a');
    a.href = resultUrl;
    a.download = resultType === 'video'
      ? `opencli-video-${Date.now()}.mp4`
      : `opencli-image-${Date.now()}.png`;
    a.click();
  };

  const handleReset = () => {
    if (resultUrl && resultUrl.startsWith('blob:')) URL.revokeObjectURL(resultUrl);
    setResultUrl(null);
    setProgress(0);
    setStatusMessage('');
    setError(null);
    setTaskId(null);
  };

  const selectScenario = (s: Scenario) => {
    setScenario(s.id);
    setMode(s.defaultMode);
    updateForm({ ...DEFAULT_FORM, ...s.defaults });
  };

  const selectMode = (m: Mode) => {
    setMode(m);
    setScenario(null);
    // Reset style to match mode
    if (m === 'txt2img') {
      updateForm({ style: 'photorealistic', provider: 'pollinations' });
    } else if (m === 'style') {
      updateForm({ style: 'face_paint_512_v2' });
    } else {
      updateForm({ style: 'cinematic', provider: 'replicate' });
    }
  };

  const currentMode = MODES.find(m => m.id === mode)!;
  const isVideoMode = mode === 'img2vid' || mode === 'txt2vid';
  const styles = mode === 'txt2img' ? IMAGE_STYLES : mode === 'style' ? [] : VIDEO_STYLES;
  const providers = isVideoMode ? VIDEO_PROVIDERS : IMAGE_PROVIDERS;
  const canGenerate = authenticated && !generating && (
    currentMode.needsImage ? !!form.imageBase64 : !!form.prompt.trim()
  );

  const generateLabel = mode === 'txt2img' ? 'Generate Image'
    : mode === 'style' ? 'Apply Style'
    : 'Generate Video';

  return (
    <div className="cr-page">
      <div className="cr-header">
        <h1>Create</h1>
        <div className={`cr-status-dot${connected && authenticated ? ' online' : ''}`} />
      </div>

      {/* Scenario Templates */}
      <div className="cr-scenarios">
        {SCENARIOS.map((s) => (
          <div
            key={s.id}
            className={`cr-scenario-card${scenario === s.id ? ' selected' : ''}`}
            onClick={() => selectScenario(s)}
          >
            <span className="material-icons cr-scenario-icon">{s.icon}</span>
            <span className="cr-scenario-label">{s.label}</span>
            <span className="cr-scenario-desc">{s.desc}</span>
          </div>
        ))}
      </div>

      {/* Mode Tabs */}
      <div className="cr-mode-tabs">
        {MODES.map((m) => (
          <button
            key={m.id}
            className={`cr-mode-tab${mode === m.id ? ' active' : ''}`}
            onClick={() => selectMode(m.id)}
          >
            <span className="material-icons">{m.icon}</span>
            {m.label}
          </button>
        ))}
      </div>

      <div className="cr-form">
        {/* Image Upload (for modes that need it) */}
        {currentMode.needsImage && (
          <div
            className={`cr-upload${dragOver ? ' drag-over' : ''}`}
            onClick={() => fileInputRef.current?.click()}
            onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
            onDragLeave={() => setDragOver(false)}
            onDrop={(e) => {
              e.preventDefault();
              setDragOver(false);
              const file = e.dataTransfer.files[0];
              if (file) handleImageFile(file);
            }}
          >
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'none' }}
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) handleImageFile(file);
              }}
            />
            {form.imagePreview ? (
              <>
                <img src={form.imagePreview} alt="Preview" className="cr-upload-preview" />
                <span className="cr-upload-filename">{form.imageName}</span>
                <button
                  className="cr-upload-remove"
                  onClick={(e) => { e.stopPropagation(); removeImage(); }}
                >
                  &times;
                </button>
              </>
            ) : (
              <>
                <span className="material-icons cr-upload-icon">cloud_upload</span>
                <span className="cr-upload-text">Drop image here or click to browse</span>
                <span className="cr-upload-hint">Supports PNG, JPG, WebP. You can also paste.</span>
              </>
            )}
          </div>
        )}

        {/* Prompt */}
        {mode !== 'style' && (
          <div className="cr-section">
            <label className="cr-label">
              {mode === 'txt2img' ? 'Prompt' : 'Prompt (optional)'}
            </label>
            <div className="cr-prompt-wrap">
              <textarea
                className="cr-prompt"
                placeholder={
                  mode === 'txt2img'
                    ? 'Describe the image you want to generate...'
                    : mode === 'txt2vid'
                    ? 'Describe the video scene you want to create...'
                    : 'Describe the motion and camera movement...'
                }
                value={form.prompt}
                onChange={(e) => updateForm({ prompt: e.target.value.slice(0, 2000) })}
                maxLength={2000}
              />
              <div className="cr-char-count">{form.prompt.length} / 2000</div>
            </div>
          </div>
        )}

        {/* Provider (not for style transfer) */}
        {mode !== 'style' && (
          <div className="cr-section">
            <label className="cr-label">Provider</label>
            <div className="cr-chips">
              {providers.map((p, idx) => {
                const isConfigured = configuredProviders.includes(p.id);
                const isRecommended = idx === 0 && configuredProviders.length > 0 && isConfigured;
                return (
                  <button
                    key={p.id}
                    className={`cr-chip${form.provider === p.id ? ' selected' : ''}${!isConfigured ? ' unconfigured' : ''}`}
                    onClick={() => updateForm({ provider: p.id })}
                    title={isConfigured ? undefined : 'API key not configured'}
                  >
                    {p.label}
                    <span className="cr-chip-sub">{p.sub}</span>
                    {isRecommended && <span className="cr-chip-badge">Best Value</span>}
                    {!isConfigured && <span className="cr-chip-badge warn">No Key</span>}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Style Grid */}
        {styles.length > 0 && (
          <div className="cr-section">
            <label className="cr-label">Style</label>
            <div className="cr-style-grid">
              {styles.map((s) => (
                <div
                  key={s.id}
                  className={`cr-style-card${form.style === s.id ? ' selected' : ''}`}
                  onClick={() => updateForm({ style: s.id })}
                >
                  <div className="cr-style-icon">
                    <span className="material-icons">{s.icon}</span>
                  </div>
                  <div className="cr-style-name">{s.label}</div>
                  <div className="cr-style-desc">{s.desc}</div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Style Transfer presets */}
        {mode === 'style' && (
          <div className="cr-section">
            <label className="cr-label">Style Preset</label>
            <div className="cr-chips">
              {STYLE_PRESETS.map((s) => (
                <button
                  key={s.id}
                  className={`cr-chip${form.style === s.id ? ' selected' : ''}`}
                  onClick={() => updateForm({ style: s.id })}
                >
                  {s.label}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Settings (duration + aspect ratio for video modes) */}
        {isVideoMode && (
          <div className="cr-section">
            <label className="cr-label">Settings</label>
            <div className="cr-settings-row">
              <div className="cr-setting-group">
                <span className="cr-setting-label">Duration</span>
                <div className="cr-chips">
                  {DURATIONS.map((d) => (
                    <button
                      key={d}
                      className={`cr-chip${form.duration === d ? ' selected' : ''}`}
                      onClick={() => updateForm({ duration: d })}
                    >
                      {d}s
                    </button>
                  ))}
                </div>
              </div>
              <div className="cr-setting-group">
                <span className="cr-setting-label">Aspect Ratio</span>
                <div className="cr-chips">
                  {ASPECT_RATIOS.map((ar) => (
                    <button
                      key={ar}
                      className={`cr-chip${form.aspectRatio === ar ? ' selected' : ''}`}
                      onClick={() => updateForm({ aspectRatio: ar })}
                    >
                      {ar}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Aspect ratio for image mode */}
        {mode === 'txt2img' && (
          <div className="cr-section">
            <label className="cr-label">Settings</label>
            <div className="cr-settings-row">
              <div className="cr-setting-group">
                <span className="cr-setting-label">Aspect Ratio</span>
                <div className="cr-chips">
                  {['1:1', '16:9', '9:16', '4:3'].map((ar) => (
                    <button
                      key={ar}
                      className={`cr-chip${form.aspectRatio === ar ? ' selected' : ''}`}
                      onClick={() => updateForm({ aspectRatio: ar })}
                    >
                      {ar}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Negative Prompt (image mode only) */}
        {mode === 'txt2img' && (
          <div className="cr-section">
            <label className="cr-label">Negative Prompt (optional)</label>
            <input
              className="cr-input"
              type="text"
              placeholder="Things to avoid: blurry, low quality, text..."
              value={form.negativePrompt}
              onChange={(e) => updateForm({ negativePrompt: e.target.value })}
            />
          </div>
        )}

        {/* Reference Image for txt2img */}
        {mode === 'txt2img' && (
          <div className="cr-section">
            <label className="cr-label">Reference Image (optional)</label>
            <div
              className={`cr-ref-upload${dragOver ? ' drag-over' : ''}`}
              onClick={() => fileInputRef.current?.click()}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
              onDrop={(e) => {
                e.preventDefault();
                setDragOver(false);
                const file = e.dataTransfer.files[0];
                if (file) handleImageFile(file);
              }}
            >
              {form.imagePreview ? (
                <>
                  <img src={form.imagePreview} alt="Reference" className="cr-ref-preview" />
                  <button
                    className="cr-ref-remove"
                    onClick={(e) => { e.stopPropagation(); removeImage(); }}
                  >
                    &times;
                  </button>
                </>
              ) : (
                <span className="cr-ref-hint">Drop reference image or click to browse</span>
              )}
            </div>
          </div>
        )}

        {/* Generate / Cancel Button */}
        {generating ? (
          <button className="cr-cancel-btn" onClick={handleCancel}>
            Cancel Generation
          </button>
        ) : (
          <button
            className="cr-generate-btn"
            disabled={!canGenerate}
            onClick={handleGenerate}
          >
            {generateLabel}
          </button>
        )}

        {/* Progress with Step Indicators */}
        {generating && (
          <div className="cr-progress">
            <div className="cr-steps">
              {PROGRESS_STEPS.map((step, i) => {
                const isActive = progress >= step.threshold;
                const isCurrent = isActive && (i === PROGRESS_STEPS.length - 1 || progress < PROGRESS_STEPS[i + 1].threshold);
                return (
                  <div key={step.id} className={`cr-step${isActive ? ' active' : ''}${isCurrent ? ' current' : ''}`}>
                    <div className="cr-step-dot" />
                    <span className="cr-step-label">{step.label}</span>
                  </div>
                );
              })}
            </div>
            <div className="cr-progress-bar">
              <div className="cr-progress-fill" style={{ width: `${progress * 100}%` }} />
            </div>
            <div className="cr-progress-info">
              <span className="cr-status-message">{statusMessage}</span>
              {startTime > 0 && progress > 0 && progress < 1 && (
                <span className="cr-eta">
                  {(() => {
                    const elapsed = (Date.now() - startTime) / 1000;
                    const avgTime = PROVIDER_ETA[form.provider] || 60;
                    const remaining = Math.max(0, Math.round(avgTime - elapsed));
                    return remaining > 0 ? `~${remaining}s remaining` : 'Almost done...';
                  })()}
                </span>
              )}
            </div>
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="cr-error">{error}</div>
        )}

        {/* Result */}
        {resultUrl && (
          <div className="cr-result">
            {resultType === 'video' ? (
              <video className="cr-result-media" src={resultUrl} controls autoPlay loop muted />
            ) : (
              <img className="cr-result-media" src={resultUrl} alt="Generated" />
            )}
            <div className="cr-result-actions">
              <button className="cr-action-btn primary" onClick={handleDownload}>
                Download
              </button>
              <button className="cr-action-btn" onClick={handleReset}>
                Generate Another
              </button>
            </div>
          </div>
        )}
        {/* Recent History */}
        {history.length > 0 && !generating && !resultUrl && (
          <div className="cr-history">
            <div className="cr-history-header">
              <span className="cr-label">Recent Generations</span>
              <button
                className="cr-history-clear"
                onClick={() => { setHistory([]); saveHistory([]); }}
              >
                Clear
              </button>
            </div>
            <div className="cr-history-list">
              {history.slice(0, 6).map((item) => (
                <div key={item.id} className="cr-history-item">
                  <div className="cr-history-icon">
                    <span className="material-icons">
                      {item.resultType === 'video' ? 'movie' : 'image'}
                    </span>
                  </div>
                  <div className="cr-history-info">
                    <span className="cr-history-prompt">
                      {item.prompt || `${item.style} ${item.resultType}`}
                    </span>
                    <span className="cr-history-meta">
                      {item.provider} · {item.style} · {new Date(item.timestamp).toLocaleDateString()}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
