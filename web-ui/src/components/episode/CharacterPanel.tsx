import { CharacterDefinition } from '../../api/episode-api';

interface Props {
  characters: CharacterDefinition[];
}

export default function CharacterPanel({ characters }: Props) {
  if (!characters || characters.length === 0) {
    return <p style={{ color: 'var(--text-secondary)' }}>No characters defined in script</p>;
  }

  return (
    <div className="characters-grid">
      {characters.map((char) => (
        <div key={char.id} className="character-card">
          <h4>{char.name}</h4>
          <p className="visual-desc">{char.visual_description || 'No visual description'}</p>
          <span className="voice-badge">
            <span className="material-icons" style={{ fontSize: 12, verticalAlign: 'middle', marginRight: 4 }}>record_voice_over</span>
            {char.default_voice || 'Default'}
          </span>
        </div>
      ))}
    </div>
  );
}
