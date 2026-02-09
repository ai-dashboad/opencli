import { useState, useEffect, useRef, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useDaemon } from '../hooks/useDaemon';
import { saveAsset } from '../utils/assetStorage';
import { storageApi } from '../utils/storageApi';
import '../styles/create.css';

type Mode = 'img2vid' | 'txt2vid' | 'txt2img' | 'style';

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

const VIDEO_PROVIDERS = [
  { id: 'pollinations', label: 'Pollinations', sub: 'Seedance ~$0.04', icon: 'eco' },
  { id: 'replicate', label: 'Replicate', sub: 'Hailuo ~$0.28', icon: 'memory' },
  { id: 'runway', label: 'Runway Gen-4', sub: '~$0.75', icon: 'rocket_launch' },
  { id: 'kling', label: 'Kling AI', sub: '~$0.90', icon: 'auto_fix_high' },
  { id: 'luma', label: 'Luma Dream', sub: '~$0.20', icon: 'wb_twilight' },
];

const IMAGE_PROVIDERS = [
  { id: 'pollinations', label: 'Pollinations', sub: 'FLUX (Free)', icon: 'eco' },
  { id: 'gemini', label: 'Google Gemini', sub: 'Imagen (Free)', icon: 'diamond' },
  { id: 'replicate', label: 'Replicate', sub: 'Flux Schnell', icon: 'memory' },
  { id: 'luma', label: 'Luma', sub: 'Photon', icon: 'wb_twilight' },
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
const ASPECT_RATIOS = ['16:9', '9:16', '1:1', '4:3', '3:4'];
const MAX_PROMPT = 5000;

const PROGRESS_STEPS = [
  { id: 'submit', label: 'Submitting', threshold: 0 },
  { id: 'queue', label: 'Queued', threshold: 0.05 },
  { id: 'process', label: 'Processing', threshold: 0.15 },
  { id: 'download', label: 'Downloading', threshold: 0.85 },
  { id: 'complete', label: 'Complete', threshold: 1.0 },
];

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

function saveHistoryItem(item: HistoryItem) {
  storageApi.addHistory({
    id: item.id,
    mode: item.mode,
    prompt: item.prompt,
    provider: item.provider,
    style: item.style,
    resultType: item.resultType,
    thumbnail: item.thumbnail,
    timestamp: item.timestamp,
  }).catch(() => {});
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

  const [mode, setMode] = useState<Mode>('txt2img');
  const [form, setForm] = useState<FormState>({ ...DEFAULT_FORM });
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [showAdvanced, setShowAdvanced] = useState(false);

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
  const [pollinationsVideoKey, setPollinationsVideoKey] = useState(false);
  const [history, setHistory] = useState<HistoryItem[]>([]);

  // Load history from API
  useEffect(() => {
    storageApi.getHistory(20).then((rows: any[]) => {
      const items: HistoryItem[] = rows.map((r: any) => ({
        id: r.id,
        mode: r.mode,
        prompt: r.prompt,
        provider: r.provider,
        style: r.style ?? '',
        resultType: r.result_type ?? r.resultType ?? 'image',
        thumbnail: r.thumbnail,
        timestamp: r.created_at ?? r.timestamp ?? Date.now(),
      }));
      setHistory(items);
    }).catch(() => {});
  }, []);

  // Fetch configured providers from daemon
  useEffect(() => {
    fetch('http://localhost:9529/api/v1/config')
      .then(r => r.json())
      .then(data => {
        const keys = data?.config?.ai_video?.api_keys || {};
        const configured = Object.entries(keys)
          .filter(([, v]) => v && typeof v === 'string' && !(v as string).startsWith('${'))
          .map(([k]) => k === 'kling_piapi' ? 'kling' : k);
        const polKey = keys['pollinations'];
        const hasPolKey = polKey && typeof polKey === 'string' && !(polKey as string).startsWith('${');
        setPollinationsVideoKey(!!hasPolKey);
        if (!configured.includes('pollinations')) configured.push('pollinations');
        const geminiKey = data?.config?.models?.gemini?.api_key;
        if (geminiKey && typeof geminiKey === 'string' && !geminiKey.startsWith('${')) {
          if (!configured.includes('gemini')) configured.push('gemini');
        }
        setConfiguredProviders(configured);
        if (configured.length > 0 && !configured.includes(form.provider)) {
          updateForm({ provider: configured[0] });
        }
      })
      .catch(() => {});
  }, []);

  // Initialize from URL params
  useEffect(() => {
    const urlPrompt = searchParams.get('prompt');
    if (urlPrompt) setForm(f => ({ ...f, prompt: urlPrompt }));
    const urlMode = searchParams.get('mode') as Mode | null;
    if (urlMode && MODES.find(m => m.id === urlMode)) setMode(urlMode);
  }, [searchParams]);

  const updateForm = (updates: Partial<FormState>) => {
    setForm(f => ({ ...f, ...updates }));
  };

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
        setProgress(prev => Math.max(prev, msg.result?.progress ?? 0));
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
          setHistory(prev => [item, ...prev].slice(0, 20));
          saveHistoryItem(item);
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

  const selectMode = (m: Mode) => {
    setMode(m);
    if (m === 'txt2img') {
      updateForm({ style: 'photorealistic', provider: 'pollinations' });
    } else if (m === 'style') {
      updateForm({ style: 'face_paint_512_v2' });
    } else {
      const videoProviderIds = VIDEO_PROVIDERS.map(p => p.id);
      const firstConfigured = configuredProviders.find(
        id => videoProviderIds.includes(id) && (id !== 'pollinations' || pollinationsVideoKey)
      );
      updateForm({ style: 'cinematic', provider: firstConfigured || 'pollinations' });
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

  const selectedProvider = providers.find(p => p.id === form.provider);

  return (
    <div className="gen-page">
      {/* Header */}
      <div className="gen-header">
        <h1 className="gen-title">Create</h1>
        <div className={`gen-conn${connected && authenticated ? ' online' : ''}`}>
          <span className="gen-conn-dot" />
          {connected && authenticated ? 'Connected' : 'Offline'}
        </div>
      </div>

      {/* Mode Tabs */}
      <div className="gen-tabs">
        {MODES.map((m) => (
          <button
            key={m.id}
            className={`gen-tab${mode === m.id ? ' active' : ''}`}
            onClick={() => selectMode(m.id)}
          >
            <span className="material-icons">{m.icon}</span>
            {m.label}
          </button>
        ))}
      </div>

      {/* Main Form */}
      <div className="gen-form-card">
        {/* Image Upload */}
        {currentMode.needsImage && (
          <div className="gen-section">
            <div className="gen-section-header">
              <label className="gen-label">Image</label>
              <span className="gen-counter">{form.imageBase64 ? '1' : '0'}/1</span>
            </div>
            <div
              className={`gen-upload${dragOver ? ' drag-over' : ''}${form.imagePreview ? ' has-image' : ''}`}
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
                <div className="gen-upload-filled">
                  <img src={form.imagePreview} alt="Preview" className="gen-upload-img" />
                  <button
                    className="gen-upload-remove"
                    onClick={(e) => { e.stopPropagation(); removeImage(); }}
                  >
                    <span className="material-icons">close</span>
                  </button>
                </div>
              ) : (
                <div className="gen-upload-empty">
                  <span className="material-icons gen-upload-icon">cloud_upload</span>
                  <span className="gen-upload-label">Click to upload an image</span>
                  <span className="gen-upload-hint">PNG, JPG, JPEG, WebP</span>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Prompt */}
        {mode !== 'style' && (
          <div className="gen-section">
            <div className="gen-section-header">
              <label className="gen-label">Prompt</label>
              <span className="gen-counter">{form.prompt.length}/{MAX_PROMPT}</span>
            </div>
            <textarea
              className="gen-textarea"
              placeholder={
                mode === 'txt2img'
                  ? 'Describe the image you want to generate...'
                  : mode === 'txt2vid'
                  ? 'Describe the video scene you want to create...'
                  : 'Describe the motion and camera movement...'
              }
              value={form.prompt}
              onChange={(e) => updateForm({ prompt: e.target.value.slice(0, MAX_PROMPT) })}
              rows={4}
            />
          </div>
        )}

        {/* Provider Selector */}
        {mode !== 'style' && (
          <div className="gen-section">
            <label className="gen-label">Model</label>
            <div className="gen-provider-grid">
              {providers.map((p) => {
                const baseConfigured = configuredProviders.includes(p.id);
                const needsVideoKey = p.id === 'pollinations' && isVideoMode && !pollinationsVideoKey;
                const isConfigured = baseConfigured && !needsVideoKey;
                return (
                  <button
                    key={p.id}
                    className={`gen-provider${form.provider === p.id ? ' selected' : ''}${!isConfigured ? ' disabled' : ''}`}
                    onClick={() => updateForm({ provider: p.id })}
                  >
                    <span className="material-icons gen-provider-icon">{p.icon}</span>
                    <div className="gen-provider-info">
                      <span className="gen-provider-name">{p.label}</span>
                      <span className="gen-provider-sub">{p.sub}</span>
                    </div>
                    {!isConfigured && <span className="gen-provider-badge">No Key</span>}
                    {form.provider === p.id && <span className="material-icons gen-provider-check">check_circle</span>}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Settings Row */}
        <div className="gen-settings">
          {/* Duration (video only) */}
          {isVideoMode && (
            <div className="gen-setting">
              <label className="gen-setting-label">Duration</label>
              <div className="gen-seg">
                {DURATIONS.map((d) => (
                  <button
                    key={d}
                    className={`gen-seg-btn${form.duration === d ? ' active' : ''}`}
                    onClick={() => updateForm({ duration: d })}
                  >
                    {d}s
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Aspect Ratio */}
          <div className="gen-setting">
            <label className="gen-setting-label">Aspect Ratio</label>
            <div className="gen-seg">
              {ASPECT_RATIOS.map((ar) => (
                <button
                  key={ar}
                  className={`gen-seg-btn${form.aspectRatio === ar ? ' active' : ''}`}
                  onClick={() => updateForm({ aspectRatio: ar })}
                >
                  {ar}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Advanced Section (collapsible) */}
        <div className="gen-advanced">
          <button
            className="gen-advanced-toggle"
            onClick={() => setShowAdvanced(!showAdvanced)}
          >
            <span className="material-icons gen-advanced-arrow">
              {showAdvanced ? 'expand_less' : 'expand_more'}
            </span>
            Advanced
          </button>

          {showAdvanced && (
            <div className="gen-advanced-body">
              {/* Style Grid */}
              {styles.length > 0 && (
                <div className="gen-section">
                  <label className="gen-label">Style</label>
                  <div className="gen-style-grid">
                    {styles.map((s) => (
                      <button
                        key={s.id}
                        className={`gen-style${form.style === s.id ? ' selected' : ''}`}
                        onClick={() => updateForm({ style: s.id })}
                      >
                        <span className="material-icons">{s.icon}</span>
                        <span className="gen-style-name">{s.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Style Transfer presets */}
              {mode === 'style' && (
                <div className="gen-section">
                  <label className="gen-label">Style Preset</label>
                  <div className="gen-seg">
                    {STYLE_PRESETS.map((s) => (
                      <button
                        key={s.id}
                        className={`gen-seg-btn${form.style === s.id ? ' active' : ''}`}
                        onClick={() => updateForm({ style: s.id })}
                      >
                        {s.label}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Negative Prompt */}
              {mode === 'txt2img' && (
                <div className="gen-section">
                  <label className="gen-label">Negative Prompt</label>
                  <input
                    className="gen-input"
                    type="text"
                    placeholder="Things to avoid: blurry, low quality, text..."
                    value={form.negativePrompt}
                    onChange={(e) => updateForm({ negativePrompt: e.target.value })}
                  />
                </div>
              )}

              {/* Reference Image for txt2img */}
              {mode === 'txt2img' && (
                <div className="gen-section">
                  <label className="gen-label">Reference Image</label>
                  <div
                    className={`gen-ref-upload${dragOver ? ' drag-over' : ''}`}
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
                        <img src={form.imagePreview} alt="Reference" className="gen-ref-img" />
                        <button
                          className="gen-ref-remove"
                          onClick={(e) => { e.stopPropagation(); removeImage(); }}
                        >
                          <span className="material-icons">close</span>
                        </button>
                      </>
                    ) : (
                      <span className="gen-ref-hint">Drop reference image or click to browse</span>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Generate / Cancel */}
        {generating ? (
          <button className="gen-btn cancel" onClick={handleCancel}>
            <span className="material-icons">stop_circle</span>
            Cancel Generation
          </button>
        ) : (
          <button
            className="gen-btn primary"
            disabled={!canGenerate}
            onClick={handleGenerate}
          >
            <span className="material-icons">auto_awesome</span>
            {generateLabel}
          </button>
        )}

        {/* Progress */}
        {generating && (
          <div className="gen-progress">
            <div className="gen-progress-steps">
              {PROGRESS_STEPS.map((step, i) => {
                const isActive = progress >= step.threshold;
                const isCurrent = isActive && (i === PROGRESS_STEPS.length - 1 || progress < PROGRESS_STEPS[i + 1].threshold);
                return (
                  <div key={step.id} className={`gen-step${isActive ? ' active' : ''}${isCurrent ? ' current' : ''}`}>
                    <div className="gen-step-dot" />
                    <span className="gen-step-label">{step.label}</span>
                  </div>
                );
              })}
            </div>
            <div className="gen-progress-track">
              <div className="gen-progress-fill" style={{ width: `${progress * 100}%` }} />
            </div>
            <div className="gen-progress-meta">
              <span className="gen-progress-msg">{statusMessage}</span>
              {startTime > 0 && progress > 0 && progress < 1 && (
                <span className="gen-progress-eta">
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
          <div className="gen-error">
            <span className="material-icons">error_outline</span>
            {error}
          </div>
        )}
      </div>

      {/* Result */}
      {resultUrl && (
        <div className="gen-result">
          <div className="gen-result-media-wrap">
            {resultType === 'video' ? (
              <video className="gen-result-media" src={resultUrl} controls autoPlay loop muted />
            ) : (
              <img className="gen-result-media" src={resultUrl} alt="Generated" />
            )}
          </div>
          <div className="gen-result-actions">
            <button className="gen-btn primary" onClick={handleDownload}>
              <span className="material-icons">download</span>
              Download
            </button>
            <button className="gen-btn secondary" onClick={handleReset}>
              <span className="material-icons">refresh</span>
              Create Another
            </button>
          </div>
        </div>
      )}

      {/* History */}
      {history.length > 0 && !generating && !resultUrl && (
        <div className="gen-history">
          <div className="gen-history-head">
            <span className="gen-label">Recent</span>
            <button
              className="gen-history-clear"
              onClick={() => { setHistory([]); storageApi.clearHistory().catch(() => {}); }}
            >
              Clear All
            </button>
          </div>
          <div className="gen-history-grid">
            {history.slice(0, 8).map((item) => (
              <div key={item.id} className="gen-history-card">
                <div className="gen-history-thumb">
                  <span className="material-icons">
                    {item.resultType === 'video' ? 'movie' : 'image'}
                  </span>
                </div>
                <span className="gen-history-label">
                  {item.prompt || `${item.style} ${item.resultType}`}
                </span>
                <span className="gen-history-meta">
                  {item.provider} &middot; {new Date(item.timestamp).toLocaleDateString()}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
