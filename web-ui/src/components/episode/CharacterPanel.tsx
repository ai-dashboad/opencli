import { useRef } from 'react';
import { CharacterDefinition } from '../../api/episode-api';

interface Props {
  characters: CharacterDefinition[];
  editable?: boolean;
  onUpdate?: (characters: CharacterDefinition[]) => void;
}

export default function CharacterPanel({ characters, editable = false, onUpdate }: Props) {
  const fileInputRefs = useRef<Record<string, HTMLInputElement | null>>({});

  if (!characters || characters.length === 0) {
    return (
      <div className="ep-empty" style={{ padding: '40px 20px' }}>
        <span className="material-icons ep-empty-icon" style={{ fontSize: 40 }}>person_off</span>
        <h3>暂无角色</h3>
        <p>AI 会根据剧本自动提取角色信息</p>
      </div>
    );
  }

  const handleImageUpload = (charId: string, file: File) => {
    if (!onUpdate) return;
    const reader = new FileReader();
    reader.onload = () => {
      const base64 = reader.result as string;
      const updated = characters.map(c =>
        c.id === charId ? { ...c, reference_image: base64 } : c
      );
      onUpdate(updated);
    };
    reader.readAsDataURL(file);
  };

  const handleRemoveImage = (charId: string) => {
    if (!onUpdate) return;
    const updated = characters.map(c =>
      c.id === charId ? { ...c, reference_image: undefined } : c
    );
    onUpdate(updated);
  };

  const handleFieldChange = (charId: string, field: keyof CharacterDefinition, value: string) => {
    if (!onUpdate) return;
    const updated = characters.map(c =>
      c.id === charId ? { ...c, [field]: value } : c
    );
    onUpdate(updated);
  };

  return (
    <div className="characters-grid">
      {characters.map((char) => (
        <div key={char.id} className="character-card">
          <div className="char-card-header">
            {/* Avatar / reference image */}
            <div
              className="char-avatar"
              onClick={() => editable && fileInputRefs.current[char.id]?.click()}
              title={editable ? '点击上传参考图' : undefined}
            >
              {char.reference_image ? (
                <img src={char.reference_image} alt={char.name} />
              ) : (
                <span className="material-icons">person</span>
              )}
              {editable && (
                <input
                  ref={el => { fileInputRefs.current[char.id] = el; }}
                  type="file"
                  accept="image/*"
                  style={{ display: 'none' }}
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) handleImageUpload(char.id, file);
                  }}
                />
              )}
            </div>
            <div style={{ flex: 1 }}>
              {editable ? (
                <input
                  type="text"
                  value={char.name}
                  onChange={(e) => handleFieldChange(char.id, 'name', e.target.value)}
                  style={{
                    width: '100%', padding: '4px 8px', borderRadius: 6,
                    border: '1px solid var(--border)', background: 'var(--bg-input)',
                    color: 'var(--text-primary)', fontSize: '0.9375rem', fontWeight: 600,
                    boxSizing: 'border-box',
                  }}
                />
              ) : (
                <h4>{char.name}</h4>
              )}
            </div>
          </div>

          {/* Reference image actions */}
          {editable && char.reference_image && (
            <div style={{ display: 'flex', gap: 6, marginBottom: 8 }}>
              <button
                className="scene-action-btn"
                onClick={() => fileInputRefs.current[char.id]?.click()}
              >
                <span className="material-icons">swap_horiz</span>
                更换参考图
              </button>
              <button
                className="scene-action-btn"
                onClick={() => handleRemoveImage(char.id)}
              >
                <span className="material-icons">close</span>
                移除
              </button>
            </div>
          )}
          {editable && !char.reference_image && (
            <button
              className="scene-action-btn"
              onClick={() => fileInputRefs.current[char.id]?.click()}
              style={{ marginBottom: 8 }}
            >
              <span className="material-icons">add_photo_alternate</span>
              上传参考图 (IP-Adapter)
            </button>
          )}

          {/* Visual description */}
          {editable ? (
            <textarea
              className="scene-edit-area"
              value={char.visual_description || ''}
              onChange={(e) => handleFieldChange(char.id, 'visual_description', e.target.value)}
              rows={2}
              placeholder="角色外观描述..."
              style={{ marginBottom: 8 }}
            />
          ) : (
            <p className="visual-desc">{char.visual_description || '暂无外观描述'}</p>
          )}

          <span className="voice-badge">
            <span className="material-icons" style={{ fontSize: 12, verticalAlign: 'middle', marginRight: 4 }}>record_voice_over</span>
            {char.default_voice || 'Default'}
          </span>
        </div>
      ))}
    </div>
  );
}
