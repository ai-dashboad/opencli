interface Props {
  progress: number;
  phases: string[];
  currentPhase: number;
  status: string;
  onCancel: () => void;
}

export default function ProgressTracker({ progress, phases, currentPhase, status, onCancel }: Props) {
  const pct = Math.round(progress * 100);

  return (
    <div className="progress-tracker">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h3 style={{ margin: 0, fontSize: '1rem' }}>Generation Progress</h3>
        <span style={{ fontSize: '1.25rem', fontWeight: 600, color: 'var(--accent)' }}>{pct}%</span>
      </div>
      <div className="progress-bar-container">
        <div className="progress-bar-fill" style={{ width: `${pct}%` }} />
      </div>
      <div className="progress-status">
        <span>{status === 'generating' ? `Phase ${currentPhase + 1}/${phases.length}` : status}</span>
        <span>{phases[currentPhase] || 'Initializing...'}</span>
      </div>
      <ul className="phase-list">
        {phases.map((phase, i) => {
          const cls = i < currentPhase ? 'done' : i === currentPhase && status === 'generating' ? 'active' : '';
          const icon = i < currentPhase ? 'check_circle' : i === currentPhase && status === 'generating' ? 'pending' : 'radio_button_unchecked';
          return (
            <li key={i} className={`phase-item ${cls}`}>
              <span className="material-icons" style={{ fontSize: 16 }}>{icon}</span>
              {phase}
            </li>
          );
        })}
      </ul>
      {status === 'generating' && (
        <button className="cancel-btn" onClick={onCancel}>Cancel Generation</button>
      )}
    </div>
  );
}
