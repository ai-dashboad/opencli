import './ModelSelector.css';

interface ModelSelectorProps {
  value: string;
  onChange: (model: string) => void;
}

const MODELS = [
  { id: 'claude', name: 'Claude Sonnet 4', provider: 'Anthropic' },
  { id: 'gpt', name: 'GPT-4 Turbo', provider: 'OpenAI' },
  { id: 'gemini', name: 'Gemini 2.0 Flash', provider: 'Google' },
  { id: 'ollama', name: 'CodeLlama', provider: 'Ollama (Local)' },
  { id: 'tinylm', name: 'TinyLM', provider: 'Embedded' },
];

export default function ModelSelector({ value, onChange }: ModelSelectorProps) {
  return (
    <div className="model-selector">
      <label>Model:</label>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        {MODELS.map((model) => (
          <option key={model.id} value={model.id}>
            {model.name} ({model.provider})
          </option>
        ))}
      </select>
    </div>
  );
}
