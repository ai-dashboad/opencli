import { EpisodeScene } from '../../api/episode-api';

interface Props {
  scene: EpisodeScene;
  index: number;
}

export default function SceneCard({ scene, index }: Props) {
  return (
    <div className="scene-card">
      <div className="scene-header">
        <h4>Scene {index + 1}: {scene.title || `Scene ${index + 1}`}</h4>
        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          ~{scene.video_duration_seconds || 5}s
        </span>
      </div>
      <p className="visual-prompt">{scene.visual_description}</p>
      {scene.setting_description && (
        <p style={{ fontSize: '0.8125rem', color: 'var(--text-secondary)', fontStyle: 'italic', margin: '4px 0' }}>
          {scene.setting_description}
        </p>
      )}
      {scene.dialogue && scene.dialogue.length > 0 && (
        <ul className="dialogue-list">
          {scene.dialogue.map((line, i) => (
            <li key={i} className="dialogue-item">
              <span className="char-name">{line.character_id}</span>
              {line.emotion && <span style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}> ({line.emotion})</span>}
              : {line.text}
            </li>
          ))}
        </ul>
      )}
      <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
        {scene.bgm_track && (
          <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', background: 'var(--bg-input)', padding: '2px 6px', borderRadius: 4 }}>
            BGM: {scene.bgm_track}
          </span>
        )}
        {scene.transition && (
          <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', background: 'var(--bg-input)', padding: '2px 6px', borderRadius: 4 }}>
            Transition: {scene.transition}
          </span>
        )}
      </div>
    </div>
  );
}
