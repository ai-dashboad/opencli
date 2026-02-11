import { useState, useEffect, useRef, useCallback } from 'react';
import { useDaemon } from '../hooks/useDaemon';
import { saveAsset } from '../utils/assetStorage';
import '../styles/create-image.css';

const PROVIDERS = [
  { id: 'replicate', label: 'Replicate', desc: 'Flux Schnell' },
  { id: 'luma', label: 'Luma', desc: 'Photon' },
];

const STYLES = [
  { id: 'photorealistic', label: 'Photorealistic', desc: 'Ultra-realistic photography', icon: 'photo_camera' },
  { id: 'digital_art', label: 'Digital Art', desc: 'Clean digital illustration', icon: 'palette' },
  { id: 'anime', label: 'Anime', desc: 'Japanese animation style', icon: 'animation' },
  { id: '3d_render', label: '3D Render', desc: 'Octane, Blender quality', icon: 'view_in_ar' },
  { id: 'watercolor', label: 'Watercolor', desc: 'Soft painterly strokes', icon: 'brush' },
  { id: 'pixel_art', label: 'Pixel Art', desc: 'Retro pixel aesthetic', icon: 'grid_on' },
];

const RESOLUTIONS = [
  { id: '1:1', label: '1:1' },
  { id: '16:9', label: '16:9' },
  { id: '9:16', label: '9:16' },
  { id: '4:3', label: '4:3' },
];

export default function CreateImagePage() {
  const { connected, authenticated, submitTask, subscribe } = useDaemon({ deviceId: 'web_image' });

  // Reference image (optional)
  const [refImage, setRefImage] = useState<string | null>(null);
  const [refImageBase64, setRefImageBase64] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Form state
  const [prompt, setPrompt] = useState('');
  const [provider, setProvider] = useState('replicate');
  const [style, setStyle] = useState('photorealistic');
  const [resolution, setResolution] = useState('1:1');
  const [negativePrompt, setNegativePrompt] = useState('');

  // Generation state
  const [generating, setGenerating] = useState(false);
  const [progress, setProgress] = useState(0);
  const [statusMessage, setStatusMessage] = useState('');
  const [resultImageUrl, setResultImageUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Handle reference image
  const handleRefImage = useCallback((file: File) => {
    if (!file.type.startsWith('image/')) return;
    const reader = new FileReader();
    reader.onload = (e) => {
      const dataUrl = e.target?.result as string;
      setRefImage(dataUrl);
      setRefImageBase64(dataUrl.split(',')[1]);
    };
    reader.readAsDataURL(file);
  }, []);

  // Paste handler
  useEffect(() => {
    const handler = (e: ClipboardEvent) => {
      const file = e.clipboardData?.files[0];
      if (file && file.type.startsWith('image/')) {
        e.preventDefault();
        handleRefImage(file);
      }
    };
    document.addEventListener('paste', handler);
    return () => document.removeEventListener('paste', handler);
  }, [handleRefImage]);

  // WS message handler
  useEffect(() => {
    const unsub = subscribe((msg: any) => {
      if (msg.type !== 'task_update') return;
      if (msg.task_type !== 'media_ai_generate_image') return;

      if (msg.status === 'running') {
        setProgress(msg.result?.progress ?? 0);
        setStatusMessage(msg.result?.status_message ?? 'Processing...');
      } else if (msg.status === 'completed') {
        setGenerating(false);
        setProgress(1);
        setStatusMessage('Complete!');
        let imageUrl: string | null = null;
        if (msg.result?.image_base64) {
          imageUrl = `data:image/png;base64,${msg.result.image_base64}`;
        } else if (msg.result?.image_url) {
          imageUrl = msg.result.image_url;
        }
        if (imageUrl) {
          setResultImageUrl(imageUrl);
          saveAsset({
            type: 'image',
            title: prompt.slice(0, 60) || 'Generated Image',
            url: imageUrl,
            thumbnail: imageUrl,
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

  const removeRefImage = () => {
    setRefImage(null);
    setRefImageBase64(null);
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const handleGenerate = () => {
    if (!prompt.trim() || generating) return;
    setGenerating(true);
    setProgress(0);
    setStatusMessage('Submitting...');
    setError(null);
    setResultImageUrl(null);

    submitTask('media_ai_generate_image', {
      prompt: prompt.trim(),
      style,
      provider,
      aspect_ratio: resolution,
      ...(negativePrompt ? { negative_prompt: negativePrompt } : {}),
      ...(refImageBase64 ? { reference_image_base64: refImageBase64 } : {}),
    });
  };

  const handleDownload = () => {
    if (!resultImageUrl) return;
    const a = document.createElement('a');
    a.href = resultImageUrl;
    a.download = `opencli-image-${Date.now()}.png`;
    a.click();
  };

  const handleGenerateAnother = () => {
    setResultImageUrl(null);
    setProgress(0);
    setStatusMessage('');
    setError(null);
  };

  const canGenerate = prompt.trim() && !generating && authenticated;

  return (
    <div className="ci-page">
      <div className="ci-header">
        <h1>Create Image</h1>
        <div className={`ci-status-dot${connected && authenticated ? ' online' : ''}`} />
      </div>

      <div className="ci-form">
        {/* Prompt */}
        <div className="ci-section">
          <label className="ci-label">Prompt</label>
          <div className="ci-prompt-wrap">
            <textarea
              className="ci-prompt"
              placeholder="Describe the image you want to generate..."
              value={prompt}
              onChange={(e) => setPrompt(e.target.value.slice(0, 2000))}
              maxLength={2000}
            />
            <div className="ci-char-count">{prompt.length} / 2000</div>
          </div>
        </div>

        {/* Style */}
        <div className="ci-section">
          <label className="ci-label">Style</label>
          <div className="ci-style-grid">
            {STYLES.map((s) => (
              <div
                key={s.id}
                className={`ci-style-card${style === s.id ? ' selected' : ''}`}
                onClick={() => setStyle(s.id)}
              >
                <div className="ci-style-icon">
                  <span className="material-icons">{s.icon}</span>
                </div>
                <div className="ci-style-name">{s.label}</div>
                <div className="ci-style-desc">{s.desc}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Provider + Resolution */}
        <div className="ci-section">
          <label className="ci-label">Settings</label>
          <div className="ci-settings-row">
            <div className="ci-setting-group">
              <span className="ci-setting-label">Provider</span>
              <div className="ci-chips">
                {PROVIDERS.map((p) => (
                  <button
                    key={p.id}
                    className={`ci-chip${provider === p.id ? ' selected' : ''}`}
                    onClick={() => setProvider(p.id)}
                  >
                    {p.label}
                    <span className="ci-chip-sub">{p.desc}</span>
                  </button>
                ))}
              </div>
            </div>
            <div className="ci-setting-group">
              <span className="ci-setting-label">Aspect Ratio</span>
              <div className="ci-chips">
                {RESOLUTIONS.map((r) => (
                  <button
                    key={r.id}
                    className={`ci-chip${resolution === r.id ? ' selected' : ''}`}
                    onClick={() => setResolution(r.id)}
                  >
                    {r.label}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Negative Prompt */}
        <div className="ci-section">
          <label className="ci-label">Negative Prompt (optional)</label>
          <input
            className="ci-input"
            type="text"
            placeholder="Things to avoid: blurry, low quality, text..."
            value={negativePrompt}
            onChange={(e) => setNegativePrompt(e.target.value)}
          />
        </div>

        {/* Reference Image (optional) */}
        <div className="ci-section">
          <label className="ci-label">Reference Image (optional)</label>
          <div
            className={`ci-ref-upload${dragOver ? ' drag-over' : ''}`}
            onClick={() => fileInputRef.current?.click()}
            onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
            onDragLeave={() => setDragOver(false)}
            onDrop={(e) => {
              e.preventDefault();
              setDragOver(false);
              const file = e.dataTransfer.files[0];
              if (file) handleRefImage(file);
            }}
          >
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'none' }}
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) handleRefImage(file);
              }}
            />
            {refImage ? (
              <>
                <img src={refImage} alt="Reference" className="ci-ref-preview" />
                <button
                  className="ci-ref-remove"
                  onClick={(e) => { e.stopPropagation(); removeRefImage(); }}
                >
                  &times;
                </button>
              </>
            ) : (
              <span className="ci-ref-hint">Drop reference image or click to browse</span>
            )}
          </div>
        </div>

        {/* Generate Button */}
        <button
          className="ci-generate-btn"
          disabled={!canGenerate}
          onClick={handleGenerate}
        >
          {generating ? 'Generating...' : 'Generate Image'}
        </button>

        {/* Progress */}
        {generating && (
          <div className="ci-progress">
            <div className="ci-progress-bar">
              <div className="ci-progress-fill" style={{ width: `${progress * 100}%` }} />
            </div>
            <span className="ci-status-message">{statusMessage}</span>
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="ci-error">{error}</div>
        )}

        {/* Result */}
        {resultImageUrl && (
          <div className="ci-result">
            <img className="ci-result-image" src={resultImageUrl} alt="Generated" />
            <div className="ci-result-actions">
              <button className="ci-action-btn primary" onClick={handleDownload}>
                Download
              </button>
              <button className="ci-action-btn" onClick={handleGenerateAnother}>
                Generate Another
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
