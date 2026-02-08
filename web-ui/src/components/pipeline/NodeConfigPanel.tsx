import type { Node } from '@xyflow/react';
import type { DomainNodeData } from './DomainNode';
import type { NodeInputPort } from '../../api/pipeline-api';
import { getTypeColor, daemonColorToCss, getDomainIcon } from './dataTypeColors';

interface NodeConfigPanelProps {
  node: Node | null;
  onUpdate: (nodeId: string, data: Partial<DomainNodeData>) => void;
  onClose: () => void;
}

export default function NodeConfigPanel({ node, onUpdate, onClose }: NodeConfigPanelProps) {
  if (!node) return null;

  const data = node.data as DomainNodeData;
  const domainColor = daemonColorToCss(data.color);
  const iconName = getDomainIcon(data.domain);

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
            <span style={{ fontSize: 11, color: '#aaa', minWidth: 30, textAlign: 'right' }}>
              {parseFloat(value) || min}
            </span>
          </div>
        );
      }

      case 'toggle':
        return (
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={!!value}
              onChange={(e) => handleParamChange(input.name, e.target.checked)}
            />
            <span style={{ fontSize: 11, color: '#aaa' }}>{value ? 'On' : 'Off'}</span>
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
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
          <span className="material-icons" style={{ fontSize: 20, color: domainColor }}>
            {iconName}
          </span>
          <div>
            <div style={{ fontSize: 12, fontWeight: 700, color: '#e0e0e0' }}>
              {data.label || data.taskType}
            </div>
            <div style={{ fontSize: 9, color: '#666', fontFamily: 'monospace' }}>
              {data.domainName} / {data.taskType}
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
                className="port-dot"
                style={{
                  background: getTypeColor(input.type),
                  display: 'inline-block',
                  width: 6,
                  height: 6,
                  borderRadius: '50%',
                  marginRight: 6,
                }}
              />
              {input.name}
              {input.type !== 'any' && (
                <span style={{ color: getTypeColor(input.type), marginLeft: 6, fontSize: 9 }}>
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
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span
                    style={{
                      width: 6,
                      height: 6,
                      borderRadius: '50%',
                      background: getTypeColor(output.type),
                      display: 'inline-block',
                    }}
                  />
                  <span style={{ fontSize: 11, color: '#aaa' }}>{output.name}</span>
                  <span style={{ fontSize: 9, color: getTypeColor(output.type) }}>{output.type}</span>
                </div>
              </div>
            ))}
          </>
        )}

        {/* Status (during execution) */}
        {data.status && (
          <>
            <div className="config-section-title">Status</div>
            <div className={`config-status config-status-${data.status}`}>
              {data.status.toUpperCase()}
            </div>
          </>
        )}

        {/* Result preview */}
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
