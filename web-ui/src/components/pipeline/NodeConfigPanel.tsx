import type { Node } from '@xyflow/react';
import type { DomainNodeData } from './DomainNode';
import type { NodeInputPort } from '../../api/pipeline-api';
import { getTypeColor, getNodeIcon } from './dataTypeColors';

interface NodeConfigPanelProps {
  node: Node | null;
  onUpdate: (nodeId: string, data: Partial<DomainNodeData>) => void;
  onClose: () => void;
}

export default function NodeConfigPanel({ node, onUpdate, onClose }: NodeConfigPanelProps) {
  if (!node) return null;

  const data = node.data as DomainNodeData;
  const icon = getNodeIcon(data.taskType);

  const handleParamChange = (key: string, value: any) => {
    onUpdate(node.id, {
      params: { ...data.params, [key]: value },
    });
  };

  const handleLabelChange = (label: string) => {
    onUpdate(node.id, { label });
  };

  const renderInput = (input: NodeInputPort) => {
    const value = data.params[input.name] ?? input.defaultValue ?? '';
    const inputType = input.inputType || 'text';

    switch (inputType) {
      case 'textarea':
        return (
          <textarea
            className="config-input config-textarea"
            value={value}
            onChange={(e) => handleParamChange(input.name, e.target.value)}
            placeholder={input.description || `Enter ${input.name}...`}
            rows={3}
          />
        );

      case 'select':
        return (
          <select
            className="config-input"
            value={value}
            onChange={(e) => handleParamChange(input.name, e.target.value)}
          >
            {!value && <option value="">Select...</option>}
            {(input.options || []).map((opt) => (
              <option key={opt} value={opt}>{opt}</option>
            ))}
          </select>
        );

      case 'slider': {
        const min = input.min ?? 0;
        const max = input.max ?? 100;
        const step = input.step ?? 1;
        return (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <input
              type="range"
              className="config-slider"
              min={min}
              max={max}
              step={step}
              value={parseFloat(value) || min}
              onChange={(e) => handleParamChange(input.name, parseFloat(e.target.value))}
            />
            <span className="config-slider-value">
              {parseFloat(value) || min}
            </span>
          </div>
        );
      }

      case 'toggle':
        return (
          <label className="config-toggle">
            <input
              type="checkbox"
              checked={!!value}
              onChange={(e) => handleParamChange(input.name, e.target.checked)}
            />
            <span className="config-toggle-label">{value ? 'On' : 'Off'}</span>
          </label>
        );

      default:
        return (
          <input
            type="text"
            className="config-input"
            value={value}
            onChange={(e) => handleParamChange(input.name, e.target.value)}
            placeholder={input.description || `Enter ${input.name}... or use {{nodeId.field}}`}
          />
        );
    }
  };

  return (
    <div className="config-panel">
      <div className="config-header">
        <span className="config-title">Node Config</span>
        <button className="config-close" onClick={onClose}>&times;</button>
      </div>

      <div className="config-body">
        {/* Node identity */}
        <div className="config-identity">
          <span className="config-icon">{icon}</span>
          <div>
            <div className="config-node-name">
              {data.label || data.taskType}
            </div>
            <div className="config-node-type">
              {data.taskType}
            </div>
          </div>
        </div>

        {/* Label */}
        <div className="config-field">
          <label className="config-label">Label</label>
          <input
            type="text"
            className="config-input"
            value={data.label || ''}
            onChange={(e) => handleLabelChange(e.target.value)}
            placeholder={data.taskType}
          />
        </div>

        {/* Input ports */}
        <div className="config-section-title">Parameters</div>
        {(data.inputs || []).map((input) => (
          <div key={input.name} className="config-field">
            <label className="config-label">
              <span
                className="config-port-dot"
                style={{ background: getTypeColor(input.type) }}
              />
              {input.name}
              {input.type !== 'any' && (
                <span className="config-port-type" style={{ color: getTypeColor(input.type) }}>
                  {input.type}
                </span>
              )}
            </label>
            {renderInput(input)}
          </div>
        ))}

        {/* Output ports */}
        {(data.outputs || []).length > 0 && (
          <>
            <div className="config-section-title">Outputs</div>
            {data.outputs.map((output) => (
              <div key={output.name} className="config-field">
                <div className="config-output-row">
                  <span
                    className="config-port-dot"
                    style={{ background: getTypeColor(output.type) }}
                  />
                  <span className="config-output-name">{output.name}</span>
                  <span className="config-output-type" style={{ color: getTypeColor(output.type) }}>{output.type}</span>
                </div>
              </div>
            ))}
          </>
        )}

        {/* Status */}
        {data.status && (
          <>
            <div className="config-section-title">Status</div>
            <div className={`config-status config-status-${data.status}`}>
              {data.status.toUpperCase()}
            </div>
          </>
        )}

        {/* Result */}
        {data.result && (
          <>
            <div className="config-section-title">Result</div>
            <pre className="config-result">
              {JSON.stringify(data.result, null, 2).substring(0, 500)}
            </pre>
          </>
        )}
      </div>
    </div>
  );
}
