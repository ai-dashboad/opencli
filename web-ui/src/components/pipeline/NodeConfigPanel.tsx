import type { Node } from '@xyflow/react';
import type { DomainNodeData } from './DomainNode';

interface NodeConfigPanelProps {
  node: Node | null;
  onUpdate: (nodeId: string, data: Partial<DomainNodeData>) => void;
  onClose: () => void;
}

export default function NodeConfigPanel({ node, onUpdate, onClose }: NodeConfigPanelProps) {
  if (!node) return null;

  const data = node.data as DomainNodeData;

  const handleParamChange = (key: string, value: string) => {
    onUpdate(node.id, {
      params: { ...data.params, [key]: value },
    });
  };

  const handleLabelChange = (label: string) => {
    onUpdate(node.id, { label });
  };

  return (
    <div className="config-panel">
      <div className="config-header">
        <span className="config-title">Node Config</span>
        <button className="config-close" onClick={onClose}>&times;</button>
      </div>

      <div className="config-body">
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

        {/* Task type (read-only) */}
        <div className="config-field">
          <label className="config-label">Task Type</label>
          <div className="config-readonly">{data.taskType}</div>
        </div>

        {/* Domain (read-only) */}
        <div className="config-field">
          <label className="config-label">Domain</label>
          <div className="config-readonly">{data.domainName}</div>
        </div>

        {/* Input ports */}
        <div className="config-section-title">Parameters</div>
        {(data.inputs || []).map((input) => (
          <div key={input.name} className="config-field">
            <label className="config-label">{input.name}</label>
            <input
              type="text"
              className="config-input"
              value={data.params[input.name] || ''}
              onChange={(e) => handleParamChange(input.name, e.target.value)}
              placeholder={`Enter ${input.name}... or use {{nodeId.field}}`}
            />
          </div>
        ))}

        {/* Status (during execution) */}
        {data.status && (
          <>
            <div className="config-section-title">Status</div>
            <div className={`config-status config-status-${data.status}`}>
              {data.status.toUpperCase()}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
