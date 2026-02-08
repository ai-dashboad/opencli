import { memo } from 'react';
import { Handle, Position, type NodeProps } from '@xyflow/react';

export interface DomainNodeData {
  label: string;
  taskType: string;
  domain: string;
  domainName: string;
  color: string;
  icon: string;
  description: string;
  params: Record<string, any>;
  inputs: { name: string; type: string }[];
  outputs: { name: string; type: string }[];
  status?: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
}

function DomainNode({ data, selected }: NodeProps & { data: DomainNodeData }) {
  const nodeData = data as DomainNodeData;
  const statusColor = {
    pending: '#666',
    running: '#2196F3',
    completed: '#4CAF50',
    failed: '#f44336',
    skipped: '#999',
  }[nodeData.status || 'pending'];

  const borderColor = selected ? '#00f0ff' : (nodeData.status ? statusColor : '#333');
  const bgColor = nodeData.status === 'running' ? 'rgba(33, 150, 243, 0.1)' :
                  nodeData.status === 'completed' ? 'rgba(76, 175, 80, 0.1)' :
                  nodeData.status === 'failed' ? 'rgba(244, 67, 54, 0.1)' :
                  'rgba(20, 20, 30, 0.95)';

  return (
    <div
      className="domain-node"
      style={{
        border: `2px solid ${borderColor}`,
        background: bgColor,
        borderRadius: 8,
        padding: '8px 12px',
        minWidth: 180,
        boxShadow: selected ? `0 0 15px ${borderColor}40` : 'none',
      }}
    >
      {/* Input handles */}
      {(nodeData.inputs || []).map((input, i) => (
        <Handle
          key={`in-${input.name}`}
          type="target"
          position={Position.Left}
          id={input.name}
          style={{
            top: `${30 + i * 24}px`,
            background: '#00f0ff',
            width: 10,
            height: 10,
            border: '2px solid #0a0118',
          }}
          title={input.name}
        />
      ))}

      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
        <span style={{
          display: 'inline-block',
          width: 8,
          height: 8,
          borderRadius: '50%',
          background: statusColor,
        }} />
        <span style={{
          fontSize: 11,
          fontWeight: 600,
          color: '#e0e0e0',
          textTransform: 'uppercase',
          letterSpacing: '0.5px',
        }}>
          {nodeData.label || nodeData.taskType}
        </span>
      </div>

      {/* Domain badge */}
      <div style={{
        fontSize: 9,
        color: '#888',
        marginBottom: 4,
        fontFamily: 'monospace',
      }}>
        {nodeData.domainName} / {nodeData.taskType}
      </div>

      {/* Params preview */}
      {Object.keys(nodeData.params || {}).length > 0 && (
        <div style={{
          fontSize: 9,
          color: '#aaa',
          borderTop: '1px solid #333',
          paddingTop: 4,
          marginTop: 4,
        }}>
          {Object.entries(nodeData.params).slice(0, 3).map(([k, v]) => (
            <div key={k} style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              <span style={{ color: '#00f0ff' }}>{k}:</span> {String(v).substring(0, 30)}
            </div>
          ))}
        </div>
      )}

      {/* Output handles */}
      {(nodeData.outputs || []).map((output, i) => (
        <Handle
          key={`out-${output.name}`}
          type="source"
          position={Position.Right}
          id={output.name}
          style={{
            top: `${30 + i * 24}px`,
            background: '#ff006e',
            width: 10,
            height: 10,
            border: '2px solid #0a0118',
          }}
          title={output.name}
        />
      ))}
    </div>
  );
}

export default memo(DomainNode);
