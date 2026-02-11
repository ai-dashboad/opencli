interface Props {
  progress: number;
  phases: string[];
  currentPhase: number;
  status: string;
  sceneCount?: number;
  onCancel: () => void;
}

const STAGES = [
  { icon: 'image', label: '画面生成', phases: [0, 1] },
  { icon: 'animation', label: '动画合成', phases: [2, 3, 4] },
  { icon: 'record_voice_over', label: '配音字幕', phases: [5, 6, 7] },
  { icon: 'movie_creation', label: '最终合成', phases: [8, 9] },
];

export default function ProgressTracker({ progress, phases, currentPhase, status, sceneCount = 0, onCancel }: Props) {
  const pct = Math.round(progress * 100);

  const getStageStatus = (stageIdx: number) => {
    const stage = STAGES[stageIdx];
    const stageStart = stage.phases[0];
    const stageEnd = stage.phases[stage.phases.length - 1];
    if (currentPhase > stageEnd) return 'done';
    if (currentPhase >= stageStart) return 'active';
    return 'pending';
  };

  // Estimate per-scene progress based on overall progress and scene count
  const getSceneProgress = (sceneIdx: number) => {
    if (sceneCount <= 0) return 0;
    const perScene = 1 / sceneCount;
    const sceneStart = sceneIdx * perScene;
    if (progress >= sceneStart + perScene) return 1;
    if (progress <= sceneStart) return 0;
    return (progress - sceneStart) / perScene;
  };

  return (
    <div className="progress-tracker">
      <div className="progress-header">
        <h3>生成进度</h3>
        <span className="progress-pct">{pct}%</span>
      </div>

      <div className="progress-bar-container">
        <div className="progress-bar-fill" style={{ width: `${pct}%` }} />
      </div>

      {/* 4 stage indicators */}
      <div className="progress-stages">
        {STAGES.map((stage, i) => {
          const s = getStageStatus(i);
          return (
            <div key={i} className={`progress-stage ${s}`}>
              <span className="material-icons progress-stage-icon">
                {s === 'done' ? 'check_circle' : s === 'active' ? stage.icon : 'radio_button_unchecked'}
              </span>
              {stage.label}
            </div>
          );
        })}
      </div>

      {/* Per-scene progress */}
      {sceneCount > 0 && (
        <div className="scene-progress-list">
          {Array.from({ length: sceneCount }, (_, i) => {
            const sp = getSceneProgress(i);
            return (
              <div key={i} className="scene-progress-item">
                <span className="scene-progress-label">场景 {i + 1}</span>
                <div className="scene-progress-bar">
                  <div className="scene-progress-bar-fill" style={{ width: `${Math.round(sp * 100)}%` }} />
                </div>
                <span className="scene-progress-status">
                  {sp >= 1 ? '✓' : sp > 0 ? `${Math.round(sp * 100)}%` : ''}
                </span>
              </div>
            );
          })}
        </div>
      )}

      {status === 'generating' && (
        <button className="cancel-btn" onClick={onCancel}>取消生成</button>
      )}
    </div>
  );
}
