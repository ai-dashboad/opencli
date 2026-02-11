import { useState, useEffect, useRef, useCallback } from 'react';
import { useDaemon } from '../hooks/useDaemon';
import { saveAsset } from '../utils/assetStorage';
import '../styles/create-video.css';

const PROVIDERS = [
  { id: 'replicate', label: 'Replicate', price: '~$0.28' },
  { id: 'runway', label: 'Runway Gen-4', price: '~$0.75' },
  { id: 'kling', label: 'Kling AI', price: '~$0.90' },
  { id: 'luma', label: 'Luma Dream', price: '~$0.20' },
];

const STYLES = [
  { id: 'cinematic', label: 'Cinematic', desc: 'Dramatic lighting, film grain', icon: 'movie' },
  { id: 'adPromo', label: 'Ad / Promo', desc: 'Commercial polish', icon: 'campaign' },
  { id: 'socialMedia', label: 'Social', desc: 'Scroll-stopping content', icon: 'share' },
  { id: 'calmAesthetic', label: 'Calm', desc: 'Soft, gentle movements', icon: 'spa' },
  { id: 'epic', label: 'Epic', desc: 'Grand dramatic sweeps', icon: 'landscape' },
  { id: 'mysterious', label: 'Mysterious', desc: 'Dark atmospheric mood', icon: 'visibility' },
];

const DURATIONS = [5, 10];
const ASPECT_RATIOS = ['16:9', '9:16', '1:1'];

export default function CreateVideoPage() {
  const { connected, authenticated, submitTask, subscribe } = useDaemon({ deviceId: 'web_video' });

  // Image state
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageBase64, setImageBase64] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Form state
  const [prompt, setPrompt] = useState('');
  const [provider, setProvider] = useState('replicate');
  const [style, setStyle] = useState('cinematic');
  const [duration, setDuration] = useState(5);
  const [aspectRatio, setAspectRatio] = useState('16:9');

  // Generation state
  const [generating, setGenerating] = useState(false);
  const [progress, setProgress] = useState(0);
  const [statusMessage, setStatusMessage] = useState('');
  const [resultVideoUrl, setResultVideoUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Handle image file
  const handleImageFile = useCallback((file: File) => {
    if (!file.type.startsWith('image/')) return;
    setImageFile(file);
    setError(null);

    const reader = new FileReader();
    reader.onload = (e) => {
      const dataUrl = e.target?.result as string;
      setImagePreview(dataUrl);
      setImageBase64(dataUrl.split(',')[1]);
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
      if (msg.task_type !== 'media_ai_generate_video') return;

      if (msg.status === 'running') {
        setProgress(msg.result?.progress ?? 0);
        setStatusMessage(msg.result?.status_message ?? 'Processing...');
      } else if (msg.status === 'completed') {
        setGenerating(false);
        setProgress(1);
        setStatusMessage('Complete!');
        if (msg.result?.video_base64) {
          const binary = atob(msg.result.video_base64);
          const bytes = new Uint8Array(binary.length);
          for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
          const blob = new Blob([bytes], { type: 'video/mp4' });
          const blobUrl = URL.createObjectURL(blob);
          setResultVideoUrl(blobUrl);
          saveAsset({
            type: 'video',
            title: prompt.slice(0, 60) || 'Generated Video',
            url: blobUrl,
            provider,
            style,
          });
        }
      } else if (msg.status === 'failed') {
        setGenerating(false);
        setError(msg.result?.message || msg.result?.error || 'Generation failed');
      }
    });
    return unsub;
  }, [subscribe, prompt, provider, style]);

  // Cleanup blob URLs
  useEffect(() => {
    return () => {
      if (resultVideoUrl) URL.revokeObjectURL(resultVideoUrl);
    };
  }, [resultVideoUrl]);

  const removeImage = () => {
    setImageFile(null);
    setImagePreview(null);
    setImageBase64(null);
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const handleGenerate = () => {
    if (!imageBase64 || generating) return;
    setGenerating(true);
    setProgress(0);
    setStatusMessage('Submitting...');
    setError(null);
    if (resultVideoUrl) {
      URL.revokeObjectURL(resultVideoUrl);
      setResultVideoUrl(null);
    }

    submitTask('media_ai_generate_video', {
      image_base64: imageBase64,
      style,
      provider,
      ...(prompt ? { custom_prompt: prompt } : {}),
      duration,
      aspect_ratio: aspectRatio,
    });
  };

  const handleDownload = () => {
    if (!resultVideoUrl) return;
    const a = document.createElement('a');
    a.href = resultVideoUrl;
    a.download = `opencli-video-${Date.now()}.mp4`;
    a.click();
  };

  const handleGenerateAnother = () => {
    if (resultVideoUrl) URL.revokeObjectURL(resultVideoUrl);
    setResultVideoUrl(null);
    setProgress(0);
    setStatusMessage('');
    setError(null);
  };

  const canGenerate = imageBase64 && !generating && authenticated;

  return (
    <div className="cv-page">
      <div className="cv-header">
        <h1>Create Video</h1>
        <div className={`cv-status-dot${connected && authenticated ? ' online' : ''}`} />
      </div>

      <div className="cv-form">
        {/* Image Upload */}
        <div
          className={`cv-upload${dragOver ? ' drag-over' : ''}`}
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
          {imagePreview ? (
            <>
              <img src={imagePreview} alt="Preview" className="cv-upload-preview" />
              <span className="cv-upload-filename">{imageFile?.name}</span>
              <button
                className="cv-upload-remove"
                onClick={(e) => { e.stopPropagation(); removeImage(); }}
              >
                &times;
              </button>
            </>
          ) : (
            <>
              <span className="material-icons cv-upload-icon">cloud_upload</span>
              <span className="cv-upload-text">Drop image here or click to browse</span>
              <span className="cv-upload-hint">Supports PNG, JPG, WebP. You can also paste.</span>
            </>
          )}
        </div>

        {/* Prompt */}
        <div className="cv-section">
          <label className="cv-label">Prompt (optional)</label>
          <div className="cv-prompt-wrap">
            <textarea
              className="cv-prompt"
              placeholder="Describe the motion and camera movement you want..."
              value={prompt}
              onChange={(e) => setPrompt(e.target.value.slice(0, 2000))}
              maxLength={2000}
            />
            <div className="cv-char-count">{prompt.length} / 2000</div>
          </div>
        </div>

        {/* Provider */}
        <div className="cv-section">
          <label className="cv-label">Provider</label>
          <div className="cv-chips">
            {PROVIDERS.map((p) => (
              <button
                key={p.id}
                className={`cv-chip${provider === p.id ? ' selected' : ''}`}
                onClick={() => setProvider(p.id)}
              >
                {p.label}
                <span className="cv-chip-price">{p.price}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Style */}
        <div className="cv-section">
          <label className="cv-label">Style</label>
          <div className="cv-style-grid">
            {STYLES.map((s) => (
              <div
                key={s.id}
                className={`cv-style-card${style === s.id ? ' selected' : ''}`}
                onClick={() => setStyle(s.id)}
              >
                <div className="cv-style-icon">
                  <span className="material-icons">{s.icon}</span>
                </div>
                <div className="cv-style-name">{s.label}</div>
                <div className="cv-style-desc">{s.desc}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Settings */}
        <div className="cv-section">
          <label className="cv-label">Settings</label>
          <div className="cv-settings-row">
            <div className="cv-setting-group">
              <span className="cv-setting-label">Duration</span>
              <div className="cv-chips">
                {DURATIONS.map((d) => (
                  <button
                    key={d}
                    className={`cv-chip${duration === d ? ' selected' : ''}`}
                    onClick={() => setDuration(d)}
                  >
                    {d}s
                  </button>
                ))}
              </div>
            </div>
            <div className="cv-setting-group">
              <span className="cv-setting-label">Aspect Ratio</span>
              <div className="cv-chips">
                {ASPECT_RATIOS.map((ar) => (
                  <button
                    key={ar}
                    className={`cv-chip${aspectRatio === ar ? ' selected' : ''}`}
                    onClick={() => setAspectRatio(ar)}
                  >
                    {ar}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Generate Button */}
        <button
          className="cv-generate-btn"
          disabled={!canGenerate}
          onClick={handleGenerate}
        >
          {generating ? 'Generating...' : 'Generate Video'}
        </button>

        {/* Progress */}
        {generating && (
          <div className="cv-progress">
            <div className="cv-progress-bar">
              <div className="cv-progress-fill" style={{ width: `${progress * 100}%` }} />
            </div>
            <span className="cv-status-message">{statusMessage}</span>
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="cv-error">{error}</div>
        )}

        {/* Result */}
        {resultVideoUrl && (
          <div className="cv-result">
            <video
              className="cv-video"
              src={resultVideoUrl}
              controls
              autoPlay
              loop
              muted
            />
            <div className="cv-result-actions">
              <button className="cv-action-btn primary" onClick={handleDownload}>
                Download
              </button>
              <button className="cv-action-btn" onClick={handleGenerateAnother}>
                Generate Another
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
