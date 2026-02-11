import { useState, useEffect, useCallback, useRef } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getEpisode, generateEpisode, getEpisodeProgress, cancelEpisode, EpisodeScript } from '../api/episode-api';
import SceneCard from '../components/episode/SceneCard';
import ProgressTracker from '../components/episode/ProgressTracker';
import CharacterPanel from '../components/episode/CharacterPanel';
import ScenePipelineEditor from '../components/episode/ScenePipelineEditor';
import '../styles/episodes.css';

type Tab = 'scenes' | 'characters' | 'pipeline' | 'generate';

const PHASES = [
  'Shot Decomposition',
  'Shot Image Generation',
  'Shot Video Animation',
  'Post-Processing',
  'Shot Assembly',
  'TTS Voice Synthesis',
  'Subtitle Generation',
  'Audio Mixing',
  'Scene Assembly',
  'Final Assembly',
];

const API_BASE = 'http://localhost:9529/api/v1';

interface Recipe {
  id: string;
  name: string;
  description: string;
  image_model: string;
  video_model: string;
  quality: string;
  controlnet_type: string;
  controlnet_scale: number;
  ip_adapter_scale: number;
  color_grade: string;
  export_platform: string;
  lora_ids: string;
}

interface LoRA {
  id: string;
  name: string;
  type: string;
  trigger_word: string;
  weight: number;
}

export default function EpisodeGenerator() {
  const { id } = useParams<{ id: string }>();
  const [script, setScript] = useState<EpisodeScript | null>(null);
  const [status, setStatus] = useState('draft');
  const [progress, setProgress] = useState(0);
  const [outputPath, setOutputPath] = useState<string | null>(null);
  const [tab, setTab] = useState<Tab>('scenes');
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const pollRef = useRef<number | null>(null);

  // Generation settings
  const [imageProvider, setImageProvider] = useState('local');
  const [videoProvider, setVideoProvider] = useState('local_v3');
  const [quality, setQuality] = useState('standard');
  const [colorGradeLut, setColorGradeLut] = useState('anime_cinematic');
  const [exportPlatform, setExportPlatform] = useState('');
  const [useControlNet, setUseControlNet] = useState(true);
  const [controlNetType, setControlNetType] = useState('lineart_anime');
  const [controlNetScale, setControlNetScale] = useState(0.7);
  const [ipAdapterScale, setIpAdapterScale] = useState(0.6);

  // Recipes + LoRAs
  const [recipes, setRecipes] = useState<Recipe[]>([]);
  const [selectedRecipe, setSelectedRecipe] = useState('');
  const [loras, setLoras] = useState<LoRA[]>([]);
  const [selectedLoras, setSelectedLoras] = useState<string[]>([]);

  // Assets
  const [assets, setAssets] = useState<any[]>([]);
  const [showAssets, setShowAssets] = useState(false);

  // Pipeline
  const [pipelineId, setPipelineId] = useState<string | null>(null);

  const fetchEpisode = useCallback(async () => {
    if (!id) return;
    try {
      const data = await getEpisode(id);
      if (data?.episode) {
        const ep = data.episode;
        const scriptData = typeof ep.script === 'string' ? JSON.parse(ep.script) : ep.script;
        setScript(scriptData);
        setStatus(ep.status || 'draft');
        setProgress(ep.progress || 0);
        setOutputPath(ep.output_path || null);
        if (ep.status === 'generating') {
          setGenerating(true);
        }
      }
    } catch (e) {
      console.error('Failed to load episode:', e);
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => { fetchEpisode(); }, [fetchEpisode]);

  // Load recipes + LoRAs
  useEffect(() => {
    fetch(`${API_BASE}/recipes`).then(r => r.json()).then(d => {
      if (d.recipes) setRecipes(d.recipes);
    }).catch(() => {});
    fetch(`${API_BASE}/loras`).then(r => r.json()).then(d => {
      if (d.loras) setLoras(d.loras);
    }).catch(() => {});
  }, []);

  // Poll progress while generating
  useEffect(() => {
    if (!generating || !id) return;
    pollRef.current = window.setInterval(async () => {
      try {
        const p = await getEpisodeProgress(id);
        setProgress(prev => Math.max(prev, p.progress || 0));
        setStatus(p.status);
        if (p.output_path) setOutputPath(p.output_path);
        if ((p as any).error) setErrorMsg((p as any).error);
        if (p.status !== 'generating') {
          setGenerating(false);
        }
      } catch (e) {
        console.error('Poll error:', e);
      }
    }, 2000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [generating, id]);

  const handleGenerate = async () => {
    if (!id) return;
    setGenerating(true);
    setProgress(0);
    setStatus('generating');
    setErrorMsg(null);
    try {
      await generateEpisode(id, {
        image_provider: imageProvider,
        video_provider: videoProvider,
        quality,
        color_grade_lut: colorGradeLut || undefined,
        export_platform: exportPlatform || undefined,
        use_pipeline: !!pipelineId,
      });
    } catch (e) {
      console.error('Generation failed:', e);
      setGenerating(false);
      setStatus('failed');
    }
  };

  const handleCancel = async () => {
    if (!id) return;
    await cancelEpisode(id);
    setGenerating(false);
    setStatus('draft');
  };

  const applyRecipe = (recipeId: string) => {
    setSelectedRecipe(recipeId);
    const recipe = recipes.find(r => r.id === recipeId);
    if (!recipe) return;
    setImageProvider(recipe.image_model || 'local');
    setVideoProvider(recipe.video_model || 'local_v3');
    setQuality(recipe.quality || 'standard');
    setControlNetType(recipe.controlnet_type || 'lineart_anime');
    setControlNetScale(recipe.controlnet_scale ?? 0.7);
    setIpAdapterScale(recipe.ip_adapter_scale ?? 0.6);
    setColorGradeLut(recipe.color_grade || '');
    setExportPlatform(recipe.export_platform || '');
    try {
      const ids = JSON.parse(recipe.lora_ids || '[]');
      setSelectedLoras(ids);
    } catch { setSelectedLoras([]); }
  };

  const fetchAssets = async () => {
    if (!id) return;
    try {
      const res = await fetch(`${API_BASE}/episodes/${id}/assets`);
      const data = await res.json();
      if (data.assets) setAssets(data.assets);
      setShowAssets(true);
    } catch { }
  };

  const toggleLora = (loraId: string) => {
    setSelectedLoras(prev =>
      prev.includes(loraId)
        ? prev.filter(id => id !== loraId)
        : [...prev, loraId]
    );
  };

  const currentPhase = Math.min(Math.floor(progress * PHASES.length), PHASES.length - 1);

  if (loading) return <div className="page-episode-gen"><p>Loading...</p></div>;
  if (!script) return <div className="page-episode-gen"><p>Episode not found</p></div>;

  return (
    <div className="page-episode-gen">
      <Link to="/episodes" className="back-link">
        <span className="material-icons" style={{ fontSize: 16 }}>arrow_back</span>
        Back to Episodes
      </Link>
      <h1>{script.title || 'Untitled Episode'}</h1>
      <p className="gen-synopsis">{script.synopsis}</p>

      <div className="gen-tabs">
        <button className={tab === 'scenes' ? 'active' : ''} onClick={() => setTab('scenes')}>
          Scenes ({script.scenes?.length || 0})
        </button>
        <button className={tab === 'characters' ? 'active' : ''} onClick={() => setTab('characters')}>
          Characters ({script.characters?.length || 0})
        </button>
        <button className={tab === 'pipeline' ? 'active' : ''} onClick={() => setTab('pipeline')}>
          Pipeline
        </button>
        <button className={tab === 'generate' ? 'active' : ''} onClick={() => setTab('generate')}>
          Generate
        </button>
      </div>

      {tab === 'scenes' && (
        <div className="scene-list">
          {(script.scenes || []).map((scene, i) => (
            <SceneCard key={scene.id || i} scene={scene} index={i} />
          ))}
          {(!script.scenes || script.scenes.length === 0) && (
            <p style={{ color: 'var(--text-secondary)' }}>No scenes in script</p>
          )}
        </div>
      )}

      {tab === 'characters' && (
        <CharacterPanel characters={script.characters || []} />
      )}

      {tab === 'pipeline' && id && (
        <ScenePipelineEditor
          episodeId={id}
          settings={{
            image_model: imageProvider === 'local_waifu' ? 'waifu_diffusion' : 'animagine_xl',
            video_model: videoProvider === 'local_v3' ? 'animatediff_v3' : videoProvider,
            quality,
            color_grade: colorGradeLut || '',
            export_platform: exportPlatform || '',
            use_controlnet: useControlNet,
            controlnet_type: controlNetType,
            controlnet_scale: controlNetScale,
          }}
          onPipelineReady={(pid) => setPipelineId(pid)}
        />
      )}

      {tab === 'generate' && (
        <>
          <div className="gen-controls">
            {/* Recipe selector */}
            {recipes.length > 0 && (
              <div style={{ marginBottom: 12 }}>
                <label>Recipe Preset</label>
                <select value={selectedRecipe} onChange={(e) => applyRecipe(e.target.value)} disabled={generating}>
                  <option value="">Custom settings</option>
                  {recipes.map(r => (
                    <option key={r.id} value={r.id}>{r.name}{r.description ? ` — ${r.description}` : ''}</option>
                  ))}
                </select>
              </div>
            )}

            <h3>Local Generation Pipeline</h3>

            {/* Image + Video provider */}
            <div className="provider-row">
              <div>
                <label>Image Model</label>
                <select value={imageProvider} onChange={(e) => setImageProvider(e.target.value)} disabled={generating}>
                  <option value="local">Animagine XL 3.1 (Best, 6.5GB)</option>
                  <option value="local_waifu">Waifu Diffusion (Faster, 2GB)</option>
                </select>
              </div>
              <div>
                <label>Video Model</label>
                <select value={videoProvider} onChange={(e) => setVideoProvider(e.target.value)} disabled={generating}>
                  <option value="local_v3">AnimateDiff V3 + MotionLoRA (Best)</option>
                  <option value="local">AnimateDiff V1</option>
                  <option value="none">Ken Burns Only (Fastest)</option>
                </select>
              </div>
            </div>

            {/* Quality + Shots estimate */}
            <div className="provider-row" style={{ marginTop: 8 }}>
              <div>
                <label>Quality Tier</label>
                <select value={quality} onChange={(e) => setQuality(e.target.value)} disabled={generating}>
                  <option value="draft">Draft — Fast, no post-processing</option>
                  <option value="standard">Standard — Real-ESRGAN + RIFE + color grade</option>
                  <option value="cinematic">Cinematic — Full post-processing + film FX</option>
                </select>
              </div>
              <div>
                <label>Estimated Shots</label>
                <div style={{ padding: '6px 0', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                  {(script?.scenes || []).length} scenes x 2-4 shots = ~{(script?.scenes || []).length * 3} shots
                </div>
              </div>
            </div>

            {/* ControlNet toggle + settings */}
            {quality !== 'draft' && (
              <div style={{ marginTop: 12, padding: '10px 14px', background: 'var(--bg-tertiary, rgba(255,255,255,0.03))', borderRadius: 8 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', margin: 0 }}>
                    <input
                      type="checkbox"
                      checked={useControlNet}
                      onChange={(e) => setUseControlNet(e.target.checked)}
                      disabled={generating}
                    />
                    ControlNet Consistency
                  </label>
                  <span style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                    Keyframe-guided video for composition stability
                  </span>
                </div>
                {useControlNet && (
                  <div className="provider-row">
                    <div>
                      <label>Control Type</label>
                      <select value={controlNetType} onChange={(e) => setControlNetType(e.target.value)} disabled={generating}>
                        <option value="lineart_anime">Lineart Anime (Best for anime)</option>
                        <option value="openpose">OpenPose (Pose-guided)</option>
                        <option value="depth">Depth (3D composition)</option>
                      </select>
                    </div>
                    <div>
                      <label>Conditioning Scale: {controlNetScale.toFixed(1)}</label>
                      <input
                        type="range" min="0.3" max="1.0" step="0.1"
                        value={controlNetScale}
                        onChange={(e) => setControlNetScale(parseFloat(e.target.value))}
                        disabled={generating}
                        style={{ width: '100%' }}
                      />
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: 'var(--text-secondary)' }}>
                        <span>Creative</span>
                        <span>Faithful</span>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* IP-Adapter scale */}
            {quality !== 'draft' && (
              <div className="provider-row" style={{ marginTop: 8 }}>
                <div>
                  <label>IP-Adapter Face Scale: {ipAdapterScale.toFixed(1)}</label>
                  <input
                    type="range" min="0.2" max="0.9" step="0.1"
                    value={ipAdapterScale}
                    onChange={(e) => setIpAdapterScale(parseFloat(e.target.value))}
                    disabled={generating}
                    style={{ width: '100%' }}
                  />
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: 'var(--text-secondary)' }}>
                    <span>Loose</span>
                    <span>Strict</span>
                  </div>
                </div>
                <div>
                  <label>Color Grade</label>
                  <select value={colorGradeLut} onChange={(e) => setColorGradeLut(e.target.value)} disabled={generating}>
                    <option value="">Default (eq + colorbalance)</option>
                    <option value="anime_cinematic">Anime Cinematic</option>
                    <option value="golden_hour">Golden Hour</option>
                    <option value="moonlit">Moonlit</option>
                    <option value="neon_city">Neon City</option>
                    <option value="sakura">Sakura</option>
                    <option value="film_noir">Film Noir</option>
                  </select>
                </div>
              </div>
            )}

            {/* Export platform */}
            {quality !== 'draft' && (
              <div className="provider-row" style={{ marginTop: 8 }}>
                <div>
                  <label>Export Platform</label>
                  <select value={exportPlatform} onChange={(e) => setExportPlatform(e.target.value)} disabled={generating}>
                    <option value="">Default (1080p 24fps)</option>
                    <option value="youtube">YouTube (1920x1080 24fps 12Mbps)</option>
                    <option value="tiktok">TikTok (1080x1920 30fps 8Mbps)</option>
                    <option value="ecommerce">E-commerce (720x1280 30fps 6Mbps)</option>
                  </select>
                </div>
                <div />
              </div>
            )}

            {/* LoRA selector */}
            {loras.length > 0 && (
              <div style={{ marginTop: 12 }}>
                <label>Style LoRAs</label>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 4 }}>
                  {loras.map(lora => (
                    <button
                      key={lora.id}
                      onClick={() => toggleLora(lora.id)}
                      disabled={generating}
                      style={{
                        padding: '4px 10px',
                        borderRadius: 14,
                        border: selectedLoras.includes(lora.id) ? '1.5px solid var(--accent)' : '1px solid var(--border)',
                        background: selectedLoras.includes(lora.id) ? 'rgba(99,102,241,0.15)' : 'transparent',
                        color: selectedLoras.includes(lora.id) ? 'var(--accent)' : 'var(--text-secondary)',
                        fontSize: '0.8rem',
                        cursor: generating ? 'default' : 'pointer',
                      }}
                    >
                      {lora.name}
                      {lora.trigger_word && <span style={{ opacity: 0.6, marginLeft: 4 }}>({lora.trigger_word})</span>}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Generate button */}
            {!generating && status !== 'completed' && (
              <button className="gen-button" onClick={handleGenerate}>
                <span className="material-icons" style={{ fontSize: 20 }}>play_arrow</span>
                Generate Episode
              </button>
            )}

            {/* Completed state */}
            {status === 'completed' && outputPath && (
              <div style={{ marginTop: 12 }}>
                <div style={{ color: 'var(--green)', display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span className="material-icons">check_circle</span>
                  Episode ready: {outputPath}
                </div>
                <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                  <button
                    onClick={fetchAssets}
                    style={{
                      padding: '6px 14px', borderRadius: 6,
                      border: '1px solid var(--border)', background: 'transparent',
                      color: 'var(--text-primary)', fontSize: '0.85rem', cursor: 'pointer'
                    }}
                  >
                    <span className="material-icons" style={{ fontSize: 16, verticalAlign: 'middle', marginRight: 4 }}>folder_open</span>
                    Browse Assets
                  </button>
                  <button
                    className="gen-button"
                    onClick={handleGenerate}
                    style={{ fontSize: '0.85rem', padding: '6px 14px' }}
                  >
                    <span className="material-icons" style={{ fontSize: 16, verticalAlign: 'middle', marginRight: 4 }}>refresh</span>
                    Re-generate
                  </button>
                </div>
              </div>
            )}

            {/* Asset browser */}
            {showAssets && assets.length > 0 && (
              <div style={{ marginTop: 12, padding: '10px 14px', background: 'var(--bg-tertiary, rgba(255,255,255,0.03))', borderRadius: 8 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <strong style={{ fontSize: '0.85rem' }}>Episode Assets ({assets.length})</strong>
                  <button onClick={() => setShowAssets(false)} style={{ background: 'none', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}>
                    <span className="material-icons" style={{ fontSize: 16 }}>close</span>
                  </button>
                </div>
                <div style={{ maxHeight: 200, overflowY: 'auto', fontSize: '0.8rem' }}>
                  {assets.map((a, i) => (
                    <div key={i} style={{
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                      padding: '3px 0', borderBottom: '1px solid var(--border)',
                    }}>
                      <span>
                        <span className="material-icons" style={{ fontSize: 14, verticalAlign: 'middle', marginRight: 4, opacity: 0.5 }}>
                          {a.type === 'image' ? 'image' : a.type === 'video' ? 'movie' : a.type === 'audio' ? 'audiotrack' : 'description'}
                        </span>
                        {a.name}
                      </span>
                      <span style={{ color: 'var(--text-secondary)' }}>
                        {(a.size_bytes / 1024).toFixed(0)} KB
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Failed state */}
            {status === 'failed' && (
              <div style={{ color: 'var(--red, #ff5252)', marginTop: 8, padding: '8px 12px', background: 'rgba(255,82,82,0.1)', borderRadius: 8, fontSize: '0.85rem' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                  <span className="material-icons" style={{ fontSize: 18 }}>error</span>
                  <strong>Generation failed</strong>
                </div>
                {errorMsg && <p style={{ margin: 0, opacity: 0.85 }}>{errorMsg}</p>}
              </div>
            )}
          </div>

          {(generating || status === 'generating') && (
            <ProgressTracker
              progress={progress}
              phases={PHASES}
              currentPhase={currentPhase}
              status={status}
              onCancel={handleCancel}
            />
          )}
        </>
      )}
    </div>
  );
}
