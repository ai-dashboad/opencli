import { EpisodeScene } from '../../api/episode-api';

interface Props {
  scene: EpisodeScene;
  index: number;
  editable?: boolean;
  onUpdate?: (scene: EpisodeScene) => void;
  onRegenerate?: (sceneIndex: number) => void;
}

export default function SceneCard({ scene, index, editable = false, onUpdate, onRegenerate }: Props) {
  const autoResize = (el: HTMLTextAreaElement) => {
    el.style.height = 'auto';
    el.style.height = el.scrollHeight + 'px';
  };

  const updateField = (field: keyof EpisodeScene, value: any) => {
    if (!onUpdate) return;
    onUpdate({ ...scene, [field]: value });
  };

  const updateDialogue = (dialogueIndex: number, field: string, value: string) => {
    if (!onUpdate || !scene.dialogue) return;
    const updated = [...scene.dialogue];
    updated[dialogueIndex] = { ...updated[dialogueIndex], [field]: value };
    onUpdate({ ...scene, dialogue: updated });
  };

  return (
    <div className="scene-card">
      <div className="scene-header">
        <h4>
          <span className="scene-index">S{index + 1}</span>
          {' '}{scene.title || `场景 ${index + 1}`}
        </h4>
        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          ~{scene.video_duration_seconds || 5}s
        </span>
      </div>

      {/* Visual description */}
      <div className="scene-field-label">画面描述</div>
      {editable ? (
        <textarea
          className="scene-edit-area"
          value={scene.visual_description || ''}
          onChange={(e) => updateField('visual_description', e.target.value)}
          onInput={(e) => autoResize(e.currentTarget)}
          rows={2}
        />
      ) : (
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem', margin: '0 0 4px' }}>
          {scene.visual_description}
        </p>
      )}

      {/* Setting description */}
      {scene.setting_description && (
        <>
          <div className="scene-field-label">场景设定</div>
          {editable ? (
            <textarea
              className="scene-edit-area"
              value={scene.setting_description || ''}
              onChange={(e) => updateField('setting_description', e.target.value)}
              onInput={(e) => autoResize(e.currentTarget)}
              rows={1}
            />
          ) : (
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem', fontStyle: 'italic', margin: '0 0 4px' }}>
              {scene.setting_description}
            </p>
          )}
        </>
      )}

      {/* Dialogue */}
      {scene.dialogue && scene.dialogue.length > 0 && (
        <div className="dialogue-section">
          <div className="scene-field-label">对白</div>
          {scene.dialogue.map((line, i) => (
            <div key={i} className="dialogue-item">
              <span className="dialogue-char">{line.character_id}</span>
              {line.emotion && <span className="dialogue-emotion">{line.emotion}</span>}
              {editable ? (
                <textarea
                  className="dialogue-text-edit"
                  value={line.text}
                  onChange={(e) => updateDialogue(i, 'text', e.target.value)}
                  onInput={(e) => autoResize(e.currentTarget)}
                  rows={1}
                />
              ) : (
                <span style={{ fontSize: '0.8125rem', flex: 1 }}>{line.text}</span>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Meta tags */}
      <div className="scene-tags">
        {scene.bgm_track && (
          <span className="scene-tag">
            <span className="material-icons">music_note</span>
            {scene.bgm_track}
          </span>
        )}
        {scene.transition && (
          <span className="scene-tag">
            <span className="material-icons">swap_horiz</span>
            {scene.transition}
          </span>
        )}
        <span className="scene-tag">
          <span className="material-icons">timer</span>
          {scene.video_duration_seconds || 5}s
        </span>
      </div>

      {/* Actions */}
      {editable && (
        <div className="scene-actions">
          <button className="scene-action-btn regen" onClick={() => onRegenerate?.(index)}>
            <span className="material-icons">refresh</span>
            重新生成此场景
          </button>
        </div>
      )}
    </div>
  );
}
