import { useState, useEffect, useCallback, useRef } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getEpisode, generateEpisode, getEpisodeProgress, cancelEpisode, updateEpisode, EpisodeScript, EpisodeScene, CharacterDefinition } from '../api/episode-api';
import SceneCard from '../components/episode/SceneCard';
import ProgressTracker from '../components/episode/ProgressTracker';
import CharacterPanel from '../components/episode/CharacterPanel';
import ScenePipelineEditor from '../components/episode/ScenePipelineEditor';
import { showToast } from '../components/Toast';
import '../styles/episodes.css';

type Tab = 'scenes' | 'characters' | 'pipeline' | 'generate';

const PHASES = [
  'Shot Decomposition', 'Shot Image Generation', 'Shot Video Animation',
  'Post-Processing', 'Shot Assembly', 'TTS Voice Synthesis',
  'Subtitle Generation', 'Audio Mixing', 'Scene Assembly', 'Final Assembly',
];

const API_BASE = 'http://localhost:9529/api/v1';

// Style presets that map to model+ControlNet+LUT combos
const STYLE_PRESETS = [
  { id: 'xianxia', name: '仙侠·水墨', desc: '水墨风格，古风仙侠', icon: '🏔️', lut: 'anime_cinematic', controlnet: 'lineart_anime' },
  { id: 'cyber', name: '赛博·霓虹', desc: '赛博朋克，霓虹灯光', icon: '🌃', lut: 'neon_city', controlnet: 'depth' },
  { id: 'sakura', name: '少女·樱花', desc: '粉色少女，温柔治愈', icon: '🌸', lut: 'sakura', controlnet: 'lineart_anime' },
  { id: 'dark', name: '暗黑·哥特', desc: '黑暗风格，阴郁氛围', icon: '🖤', lut: 'film_noir', controlnet: 'depth' },
  { id: 'golden', name: '黄昏·暖调', desc: '金色暖光，怀旧温馨', icon: '🌅', lut: 'golden_hour', controlnet: 'lineart_anime' },
  { id: 'moonlit', name: '月夜·冷调', desc: '月光冷色，神秘幽寂', icon: '🌙', lut: 'moonlit', controlnet: 'openpose' },
];

const TIMELINE_COLORS = [
  '#6C5CE7', '#2563EB', '#059669', '#D97706', '#DC2626', '#7C3AED',
  '#0891B2', '#65A30D', '#CA8A04', '#E11D48',
];

interface Recipe {
  id: string; name: string; description: string;
  image_model: string; video_model: string; quality: string;
  controlnet_type: string; controlnet_scale: number;
  ip_adapter_scale: number; color_grade: string;
  export_platform: string; lora_ids: string;
}

interface LoRA {
  id: string; name: string; type: string; trigger_word: string; weight: number;
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
  const [editMode, setEditMode] = useState(false);
  const [dirty, setDirty] = useState(false);
  const pollRef = useRef<number | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);

  // Generation settings
  const [stylePreset, setStylePreset] = useState('xianxia');
  const [quality, setQuality] = useState('standard');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [imageProvider, setImageProvider] = useState('local');
  const [videoProvider, setVideoProvider] = useState('local_v3');
  const [colorGradeLut, setColorGradeLut] = useState('anime_cinematic');
  const [exportPlatform, setExportPlatform] = useState('');
  const [useControlNet, setUseControlNet] = useState(true);
  const [controlNetType, setControlNetType] = useState('lineart_anime');
  const [controlNetScale, setControlNetScale] = useState(0.7);
  const [ipAdapterScale, setIpAdapterScale] = useState(0.6);

  // Export settings
  const [showExportPanel, setShowExportPanel] = useState(false);
  const [exportFormat, setExportFormat] = useState('mp4');
  const [exportRatio, setExportRatio] = useState('16:9');
  const [exportSubtitle, setExportSubtitle] = useState('hard');

  // Recipes + LoRAs
  const [recipes, setRecipes] = useState<Recipe[]>([]);
  const [loras, setLoras] = useState<LoRA[]>([]);
  const [selectedLoras, setSelectedLoras] = useState<string[]>([]);

  // Pipeline
  const [pipelineId, setPipelineId] = useState<string | null>(null);

  // Active scene in timeline + drag state
  const [activeScene, setActiveScene] = useState(0);
  const [dragIndex, setDragIndex] = useState<number | null>(null);
  const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);

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
        if (ep.status === 'generating') setGenerating(true);
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
        if (p.status !== 'generating') setGenerating(false);
      } catch (e) { console.error('Poll error:', e); }
    }, 2000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [generating, id]);

  // Apply style preset
  const applyPreset = (presetId: string) => {
    setStylePreset(presetId);
    const preset = STYLE_PRESETS.find(p => p.id === presetId);
    if (!preset) return;
    setColorGradeLut(preset.lut);
    setControlNetType(preset.controlnet);
  };

  const handleGenerate = async () => {
    if (!id) return;
    setGenerating(true);
    setProgress(0);
    setStatus('generating');
    setErrorMsg(null);
    setTab('generate');
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

  // Scene editing
  const handleSceneUpdate = (index: number, updatedScene: EpisodeScene) => {
    if (!script) return;
    const scenes = [...(script.scenes || [])];
    scenes[index] = updatedScene;
    setScript({ ...script, scenes });
    setDirty(true);
  };

  // Character editing
  const handleCharactersUpdate = (updatedChars: CharacterDefinition[]) => {
    if (!script) return;
    setScript({ ...script, characters: updatedChars });
    setDirty(true);
  };

  const handleSaveScript = async () => {
    if (!id || !script) return;
    try {
      await updateEpisode(id, script);
      setDirty(false);
      showToast('剧本已保存', 'success');
    } catch (e) {
      showToast('保存失败', 'error');
    }
  };

  const handleRegenScene = (sceneIndex: number) => {
    showToast(`场景 ${sceneIndex + 1} 将在下次生成时更新`, 'info');
  };

  // Scene drag-and-drop reordering
  const handleDragStart = (index: number) => {
    setDragIndex(index);
  };

  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault();
    if (dragIndex === null || dragIndex === index) return;
    setDragOverIndex(index);
  };

  const handleDrop = (index: number) => {
    if (dragIndex === null || !script) return;
    const scenes = [...(script.scenes || [])];
    const [moved] = scenes.splice(dragIndex, 1);
    scenes.splice(index, 0, moved);
    setScript({ ...script, scenes });
    setDirty(true);
    setDragIndex(null);
    setDragOverIndex(null);
  };

  const handleDragEnd = () => {
    setDragIndex(null);
    setDragOverIndex(null);
  };

  const currentPhase = Math.min(Math.floor(progress * PHASES.length), PHASES.length - 1);
  const totalDuration = (script?.scenes || []).reduce((sum, s) => sum + (s.video_duration_seconds || 5), 0);

  const handleDownload = () => {
    if (!outputPath) return;
    const a = document.createElement('a');
    a.href = outputPath;
    a.download = `${script?.title || 'episode'}.mp4`;
    a.click();
  };

  if (loading) return <div className="page-episode-gen"><p>加载中...</p></div>;
  if (!script) return <div className="page-episode-gen"><p>未找到该作品</p></div>;

  return (
    <div className="page-episode-gen">
      <Link to="/episodes" className="back-link">
        <span className="material-icons" style={{ fontSize: 16 }}>arrow_back</span>
        返回作品列表
      </Link>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
        <div>
          <h1>{script.title || '未命名作品'}</h1>
          <p className="gen-synopsis">{script.synopsis}</p>
        </div>
        <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
          {status === 'completed' && outputPath && (
            <button className="ep-create-btn" onClick={() => setShowExportPanel(true)} style={{ background: 'var(--green)' }}>
              <span className="material-icons" style={{ fontSize: 16 }}>download</span>
              导出
            </button>
          )}
          {status !== 'generating' && (
            <button className="ep-create-btn" onClick={handleGenerate}>
              <span className="material-icons" style={{ fontSize: 16 }}>play_arrow</span>
              {status === 'completed' ? '重新生成' : '开始生成'}
            </button>
          )}
        </div>
      </div>

      {/* Video Player */}
      <div className="ep-player-section">
        {outputPath && status === 'completed' ? (
          <video
            ref={videoRef}
            className="ep-player-video"
            src={outputPath}
            controls
            preload="metadata"
          />
        ) : (
          <div className="ep-player-empty">
            <span className="material-icons">
              {status === 'generating' ? 'hourglass_top' : 'smart_display'}
            </span>
            <span>
              {status === 'generating' ? '正在生成中...' : '生成完成后在此预览'}
            </span>
          </div>
        )}
      </div>

      {/* Timeline */}
      {(script.scenes || []).length > 0 && (
        <div className="ep-timeline">
          <div className="ep-timeline-header">
            <h4>
              <span className="material-icons" style={{ fontSize: 16, verticalAlign: 'middle', marginRight: 4 }}>timeline</span>
              时间线
            </h4>
            <span className="ep-timeline-total">
              {(script.scenes || []).length} 场景 · 约 {totalDuration}s
            </span>
          </div>
          <div className="ep-timeline-track">
            {(script.scenes || []).map((scene, i) => {
              const dur = scene.video_duration_seconds || 5;
              const widthPct = (dur / totalDuration) * 100;
              return (
                <div
                  key={i}
                  className={`ep-timeline-scene${activeScene === i ? ' active' : ''}`}
                  style={{ width: `${widthPct}%`, background: TIMELINE_COLORS[i % TIMELINE_COLORS.length] }}
                  onClick={() => setActiveScene(i)}
                  title={`${scene.title || `S${i + 1}`} (${dur}s)`}
                >
                  S{i + 1}
                </div>
              );
            })}
          </div>
          <div className="ep-timeline-audio">
            <span className="material-icons" style={{ fontSize: 14 }}>music_note</span>
            BGM
            <div className="ep-timeline-audio-bar" />
          </div>
          <div className="ep-timeline-audio">
            <span className="material-icons" style={{ fontSize: 14 }}>record_voice_over</span>
            TTS
            <div className="ep-timeline-audio-bar" />
          </div>
        </div>
      )}

      {/* Progress tracker (when generating) */}
      {(generating || status === 'generating') && (
        <ProgressTracker
          progress={progress}
          phases={PHASES}
          currentPhase={currentPhase}
          status={status}
          sceneCount={(script?.scenes || []).length}
          onCancel={handleCancel}
        />
      )}

      {/* Failed state */}
      {status === 'failed' && errorMsg && (
        <div style={{
          margin: '16px 0', padding: '12px 16px', borderRadius: 10,
          background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.2)',
          display: 'flex', alignItems: 'center', gap: 8, color: 'var(--red)', fontSize: '0.85rem'
        }}>
          <span className="material-icons" style={{ fontSize: 18 }}>error</span>
          {errorMsg}
        </div>
      )}

      {/* Tabs */}
      <div className="gen-tabs">
        <button className={tab === 'scenes' ? 'active' : ''} onClick={() => setTab('scenes')}>
          场景 ({(script.scenes || []).length})
        </button>
        <button className={tab === 'characters' ? 'active' : ''} onClick={() => setTab('characters')}>
          角色 ({(script.characters || []).length})
        </button>
        <button className={tab === 'generate' ? 'active' : ''} onClick={() => setTab('generate')}>
          生成设置
        </button>
        <button className={tab === 'pipeline' ? 'active' : ''} onClick={() => setTab('pipeline')}>
          高级
        </button>
      </div>

      {/* Scenes tab */}
      {tab === 'scenes' && (
        <>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <button
              onClick={() => setEditMode(!editMode)}
              style={{
                display: 'flex', alignItems: 'center', gap: 6,
                padding: '6px 14px', borderRadius: 8,
                border: `1px solid ${editMode ? 'var(--accent)' : 'var(--border)'}`,
                background: editMode ? 'var(--accent-dim)' : 'transparent',
                color: editMode ? 'var(--accent)' : 'var(--text-secondary)',
                fontSize: '0.8125rem', cursor: 'pointer',
              }}
            >
              <span className="material-icons" style={{ fontSize: 16 }}>{editMode ? 'check' : 'edit'}</span>
              {editMode ? '编辑中' : '编辑场景'}
            </button>
            {dirty && (
              <button className="ep-create-btn" onClick={handleSaveScript} style={{ padding: '6px 16px', fontSize: '0.8125rem' }}>
                <span className="material-icons" style={{ fontSize: 16 }}>save</span>
                保存修改
              </button>
            )}
          </div>
          {editMode && (
            <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', margin: '0 0 12px', display: 'flex', alignItems: 'center', gap: 4 }}>
              <span className="material-icons" style={{ fontSize: 14 }}>drag_indicator</span>
              拖拽场景卡片可调整顺序
            </p>
          )}
          <div className="scene-list">
            {(script.scenes || []).map((scene, i) => (
              <div
                key={scene.id || i}
                draggable={editMode}
                onDragStart={() => handleDragStart(i)}
                onDragOver={(e) => handleDragOver(e, i)}
                onDrop={() => handleDrop(i)}
                onDragEnd={handleDragEnd}
                className={`scene-drag-wrapper${dragOverIndex === i ? ' drag-over' : ''}${dragIndex === i ? ' dragging' : ''}`}
              >
                {editMode && (
                  <div className="scene-drag-handle">
                    <span className="material-icons">drag_indicator</span>
                  </div>
                )}
                <SceneCard
                  scene={scene}
                  index={i}
                  editable={editMode}
                  onUpdate={(s) => handleSceneUpdate(i, s)}
                  onRegenerate={handleRegenScene}
                />
              </div>
            ))}
          </div>
        </>
      )}

      {/* Characters tab */}
      {tab === 'characters' && (
        <>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <button
              onClick={() => setEditMode(!editMode)}
              style={{
                display: 'flex', alignItems: 'center', gap: 6,
                padding: '6px 14px', borderRadius: 8,
                border: `1px solid ${editMode ? 'var(--accent)' : 'var(--border)'}`,
                background: editMode ? 'var(--accent-dim)' : 'transparent',
                color: editMode ? 'var(--accent)' : 'var(--text-secondary)',
                fontSize: '0.8125rem', cursor: 'pointer',
              }}
            >
              <span className="material-icons" style={{ fontSize: 16 }}>{editMode ? 'check' : 'edit'}</span>
              {editMode ? '编辑中' : '编辑角色'}
            </button>
            {dirty && (
              <button className="ep-create-btn" onClick={handleSaveScript} style={{ padding: '6px 16px', fontSize: '0.8125rem' }}>
                <span className="material-icons" style={{ fontSize: 16 }}>save</span>
                保存修改
              </button>
            )}
          </div>
          <CharacterPanel
            characters={script.characters || []}
            editable={editMode}
            onUpdate={handleCharactersUpdate}
          />
        </>
      )}

      {/* Generate settings tab */}
      {tab === 'generate' && (
        <div className="gen-controls">
          <h3>风格预设</h3>
          <div className="style-presets">
            {STYLE_PRESETS.map(preset => (
              <div
                key={preset.id}
                className={`style-preset-card${stylePreset === preset.id ? ' active' : ''}`}
                onClick={() => { if (!generating) applyPreset(preset.id); }}
              >
                <div className="style-preset-icon">{preset.icon}</div>
                <div className="style-preset-name">{preset.name}</div>
                <div className="style-preset-desc">{preset.desc}</div>
              </div>
            ))}
          </div>

          <h3>画质</h3>
          <div className="quality-selector">
            {[
              { id: 'draft', label: '草稿', desc: '快速预览' },
              { id: 'standard', label: '标准', desc: '后期处理 + 调色' },
              { id: 'cinematic', label: '极致', desc: '全后期 + 电影级' },
            ].map(q => (
              <button
                key={q.id}
                className={`quality-option${quality === q.id ? ' active' : ''}`}
                onClick={() => { if (!generating) setQuality(q.id); }}
                disabled={generating}
              >
                <span className="quality-option-label">{q.label}</span>
                <span className="quality-option-desc">{q.desc}</span>
              </button>
            ))}
          </div>

          {/* Advanced settings (collapsed by default) */}
          <button className="advanced-toggle" onClick={() => setShowAdvanced(!showAdvanced)}>
            <span className="material-icons" style={{ fontSize: 18 }}>{showAdvanced ? 'expand_less' : 'expand_more'}</span>
            高级设置
          </button>

          {showAdvanced && (
            <div className="advanced-panel">
              <div className="provider-row">
                <div>
                  <label>图像模型</label>
                  <select value={imageProvider} onChange={(e) => setImageProvider(e.target.value)} disabled={generating}>
                    <option value="local">Animagine XL 3.1 (6.5GB)</option>
                    <option value="local_waifu">Waifu Diffusion (2GB)</option>
                  </select>
                </div>
                <div>
                  <label>视频模型</label>
                  <select value={videoProvider} onChange={(e) => setVideoProvider(e.target.value)} disabled={generating}>
                    <option value="local_v3">AnimateDiff V3 + MotionLoRA</option>
                    <option value="local">AnimateDiff V1</option>
                    <option value="none">Ken Burns (最快)</option>
                  </select>
                </div>
              </div>

              {quality !== 'draft' && (
                <>
                  <div className="provider-row">
                    <div>
                      <label style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <input type="checkbox" checked={useControlNet} onChange={(e) => setUseControlNet(e.target.checked)} disabled={generating} />
                        ControlNet 画面一致性
                      </label>
                      {useControlNet && (
                        <select value={controlNetType} onChange={(e) => setControlNetType(e.target.value)} disabled={generating} style={{ marginTop: 6 }}>
                          <option value="lineart_anime">Lineart Anime</option>
                          <option value="openpose">OpenPose</option>
                          <option value="depth">Depth</option>
                        </select>
                      )}
                    </div>
                    <div>
                      <label>ControlNet 强度: {controlNetScale.toFixed(1)}</label>
                      <input type="range" min="0.3" max="1.0" step="0.1" value={controlNetScale}
                        onChange={(e) => setControlNetScale(parseFloat(e.target.value))} disabled={generating}
                        style={{ width: '100%' }} />
                    </div>
                  </div>
                  <div className="provider-row">
                    <div>
                      <label>IP-Adapter 面部一致性: {ipAdapterScale.toFixed(1)}</label>
                      <input type="range" min="0.2" max="0.9" step="0.1" value={ipAdapterScale}
                        onChange={(e) => setIpAdapterScale(parseFloat(e.target.value))} disabled={generating}
                        style={{ width: '100%' }} />
                    </div>
                    <div>
                      <label>色彩调色</label>
                      <select value={colorGradeLut} onChange={(e) => setColorGradeLut(e.target.value)} disabled={generating}>
                        <option value="">默认</option>
                        <option value="anime_cinematic">动漫电影</option>
                        <option value="golden_hour">黄金时刻</option>
                        <option value="moonlit">月光</option>
                        <option value="neon_city">霓虹城市</option>
                        <option value="sakura">樱花</option>
                        <option value="film_noir">黑色电影</option>
                      </select>
                    </div>
                  </div>
                  <div className="provider-row">
                    <div>
                      <label>导出平台</label>
                      <select value={exportPlatform} onChange={(e) => setExportPlatform(e.target.value)} disabled={generating}>
                        <option value="">默认 (1080p 24fps)</option>
                        <option value="youtube">YouTube (1920x1080)</option>
                        <option value="tiktok">TikTok (1080x1920)</option>
                        <option value="ecommerce">电商 (720x1280)</option>
                      </select>
                    </div>
                    <div />
                  </div>
                </>
              )}

              {/* LoRA selector */}
              {loras.length > 0 && (
                <div style={{ marginTop: 8 }}>
                  <label>风格 LoRA</label>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 4 }}>
                    {loras.map(lora => (
                      <button key={lora.id} onClick={() => setSelectedLoras(prev =>
                        prev.includes(lora.id) ? prev.filter(x => x !== lora.id) : [...prev, lora.id]
                      )} disabled={generating} style={{
                        padding: '4px 10px', borderRadius: 14,
                        border: selectedLoras.includes(lora.id) ? '1.5px solid var(--accent)' : '1px solid var(--border)',
                        background: selectedLoras.includes(lora.id) ? 'rgba(99,102,241,0.15)' : 'transparent',
                        color: selectedLoras.includes(lora.id) ? 'var(--accent)' : 'var(--text-secondary)',
                        fontSize: '0.8rem', cursor: generating ? 'default' : 'pointer',
                      }}>
                        {lora.name}
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Generate button */}
          {!generating && (
            <button className="gen-button" onClick={handleGenerate} style={{ width: '100%', justifyContent: 'center' }}>
              <span className="material-icons" style={{ fontSize: 20 }}>auto_awesome</span>
              {status === 'completed' ? '重新生成' : '开始生成'}
            </button>
          )}
        </div>
      )}

      {/* Pipeline (advanced) tab */}
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

      {/* Export panel modal */}
      {showExportPanel && (
        <div className="modal-overlay" onClick={() => setShowExportPanel(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 480 }}>
            <div className="export-panel" style={{ border: 'none', padding: 0 }}>
              <h3>导出设置</h3>

              <div className="export-option-group">
                <label>格式</label>
                <div className="export-chips">
                  {[
                    { id: 'mp4', label: 'MP4 (H.264)' },
                    { id: 'webm', label: 'WebM (VP9)' },
                    { id: 'mov', label: 'MOV (ProRes)' },
                  ].map(f => (
                    <button
                      key={f.id}
                      className={`export-chip${exportFormat === f.id ? ' active' : ''}`}
                      onClick={() => setExportFormat(f.id)}
                    >
                      {f.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="export-option-group">
                <label>画面比例</label>
                <div className="export-chips">
                  {[
                    { id: '16:9', label: '16:9 横屏' },
                    { id: '9:16', label: '9:16 竖屏' },
                    { id: '1:1', label: '1:1 方形' },
                  ].map(r => (
                    <button
                      key={r.id}
                      className={`export-chip${exportRatio === r.id ? ' active' : ''}`}
                      onClick={() => setExportRatio(r.id)}
                    >
                      {r.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="export-option-group">
                <label>字幕</label>
                <div className="export-chips">
                  {[
                    { id: 'hard', label: '硬字幕 (烧录)' },
                    { id: 'soft', label: '软字幕 (可关闭)' },
                    { id: 'none', label: '无字幕' },
                  ].map(s => (
                    <button
                      key={s.id}
                      className={`export-chip${exportSubtitle === s.id ? ' active' : ''}`}
                      onClick={() => setExportSubtitle(s.id)}
                    >
                      {s.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="export-actions">
                <button
                  style={{
                    padding: '8px 20px', borderRadius: 8,
                    border: '1px solid var(--border)', background: 'var(--bg-surface)',
                    color: 'var(--text-primary)', cursor: 'pointer', fontSize: '0.875rem',
                  }}
                  onClick={() => setShowExportPanel(false)}
                >
                  取消
                </button>
                <button className="ep-create-btn" style={{ background: 'var(--green)' }} onClick={() => {
                  handleDownload();
                  setShowExportPanel(false);
                  showToast('导出已开始', 'success');
                }}>
                  <span className="material-icons" style={{ fontSize: 16 }}>download</span>
                  导出视频
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
