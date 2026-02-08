import { memo, useCallback } from 'react';
import { Handle, Position, useReactFlow, type NodeProps } from '@xyflow/react';
import type { NodeInputPort, NodeOutputPort } from '../../api/pipeline-api';
import { getTypeColor, daemonColorToCss, getDomainIcon } from './dataTypeColors';
import { usePipelineContext } from './PipelineContext';
import InlineParamInput from './InlineParamInput';
import NodeResultPreview from './NodeResultPreview';

export interface DomainNodeData {
  label: string;
  taskType: string;
  domain: string;
  domainName: string;
  color: string;
  icon: string;
  description: string;
  params: Record<string, any>;
  inputs: NodeInputPort[];
  outputs: NodeOutputPort[];
  status?: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  result?: Record<string, any>;
  error?: string;
}

const HEADER_HEIGHT = 44;
const ROW_HEIGHT = 36;
const TEXTAREA_EXTRA = 32;

function DomainNode({ id, data, selected }: NodeProps & { data: DomainNodeData }) {
  const nodeData = data as DomainNodeData;
  const { setNodes } = useReactFlow();
  const { onPlayFromHere, isRunning } = usePipelineContext();

  const statusColor = {
    pending: '#555',
    running: '#2196F3',
    completed: '#4CAF50',
    failed: '#f44336',
    skipped: '#777',
  }[nodeData.status || 'pending'];

  const borderColor = selected
    ? '#00f0ff'
    : nodeData.status && nodeData.status !== 'pending'
    ? statusColor
    : '#333';

  const bgColor =
    nodeData.status === 'running'
      ? 'rgba(33, 150, 243, 0.08)'
      : nodeData.status === 'completed'
      ? 'rgba(76, 175, 80, 0.08)'
      : nodeData.status === 'failed'
      ? 'rgba(244, 67, 54, 0.08)'
      : 'rgba(18, 18, 28, 0.97)';

  const domainColor = daemonColorToCss(nodeData.color);
  const iconName = getDomainIcon(nodeData.domain);

  const handleParamChange = useCallback(
    (name: string, value: any) => {
      setNodes((nds) =>
        nds.map((n) =>
          n.id === id
            ? {
                ...n,
                data: {
                  ...n.data,
                  params: { ...(n.data as DomainNodeData).params, [name]: value },
                },
              }
            : n
        )
      );
    },
    [id, setNodes]
  );

  const handlePlay = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      onPlayFromHere(id);
    },
    [id, onPlayFromHere]
  );

  // Calculate handle positions
  const inputs = nodeData.inputs || [];
  const outputs = nodeData.outputs || [];

  // Calculate input row offsets (account for textarea extra height)
  const inputOffsets: number[] = [];
  let currentY = HEADER_HEIGHT;
  for (const input of inputs) {
    const isTextarea = input.inputType === 'textarea';
    const rowH = isTextarea ? ROW_HEIGHT + TEXTAREA_EXTRA : ROW_HEIGHT;
    inputOffsets.push(currentY + rowH / 2);
    currentY += rowH;
  }

  // Output handles at bottom section
  const resultSectionY = currentY + (nodeData.result || nodeData.status === 'running' ? 40 : 0);
  const outputOffsets = outputs.map((_, i) => resultSectionY + 10 + i * 24);

  return (
    <div
      className="domain-node-v2"
      style={{
        border: `2px solid ${borderColor}`,
        background: bgColor,
        borderRadius: 10,
        minWidth: 280,
        maxWidth: 400,
        boxShadow: selected
          ? `0 0 20px ${borderColor}30`
          : '0 2px 8px rgba(0,0,0,0.3)',
        overflow: 'visible',
      }}
    >
      {/* Input handles */}
      {inputs.map((input, i) => (
        <Handle
          key={`in-${input.name}`}
          type="target"
          position={Position.Left}
          id={input.name}
          style={{
            top: `${inputOffsets[i]}px`,
            background: getTypeColor(input.type),
            width: 10,
            height: 10,
            border: '2px solid #111',
          }}
        />
      ))}

      {/* Header */}
      <div
        className="node-header"
        style={{
          borderBottom: '1px solid #2a2a3e',
          padding: '8px 12px',
          display: 'flex',
          alignItems: 'center',
          gap: 8,
        }}
      >
        <span
          className="material-icons"
          style={{ fontSize: 18, color: domainColor }}
        >
          {iconName}
        </span>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              fontSize: 12,
              fontWeight: 700,
              color: '#e8e8e8',
              letterSpacing: '0.3px',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {nodeData.label || nodeData.taskType}
          </div>
          <div style={{ fontSize: 9, color: '#666', fontFamily: 'monospace' }}>
            {nodeData.domainName} / {nodeData.taskType}
          </div>
        </div>
        {/* Status dot */}
        <span
          style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: statusColor,
            flexShrink: 0,
          }}
        />
        {/* Play from here button */}
        <button
          className="node-play-btn nodrag nopan"
          onClick={handlePlay}
          disabled={isRunning}
          title="Play from here"
        >
          <span className="material-icons" style={{ fontSize: 16 }}>
            play_arrow
          </span>
        </button>
      </div>

      {/* Input ports with inline controls */}
      <div style={{ padding: '4px 0' }}>
        {inputs.map((input, i) => (
          <div
            key={input.name}
            className="node-port-row"
            style={{ padding: '4px 12px' }}
          >
            <div className="port-label-row">
              <span
                className="port-dot"
                style={{ background: getTypeColor(input.type) }}
              />
              <span className="port-label">{input.name}</span>
              {input.type !== 'any' && (
                <span
                  className="port-type-badge"
                  style={{ color: getTypeColor(input.type) }}
                >
                  {input.type}
                </span>
              )}
            </div>
            <InlineParamInput
              port={input}
              value={nodeData.params[input.name]}
              onChange={handleParamChange}
            />
          </div>
        ))}
      </div>

      {/* Result preview */}
      <NodeResultPreview
        status={nodeData.status}
        result={nodeData.result}
        error={nodeData.error}
      />

      {/* Output handles */}
      {outputs.map((output, i) => (
        <Handle
          key={`out-${output.name}`}
          type="source"
          position={Position.Right}
          id={output.name}
          style={{
            top: `${outputOffsets[i] || 'auto'}`,
            bottom: outputs.length === 1 ? '12px' : 'auto',
            background: getTypeColor(output.type),
            width: 10,
            height: 10,
            border: '2px solid #111',
          }}
        />
      ))}

      {/* Output port labels (bottom) */}
      {outputs.length > 0 && (
        <div
          style={{
            borderTop: '1px solid #2a2a3e',
            padding: '4px 12px 6px',
          }}
        >
          {outputs.map((output) => (
            <div
              key={output.name}
              className="port-label-row"
              style={{ justifyContent: 'flex-end' }}
            >
              <span
                className="port-type-badge"
                style={{ color: getTypeColor(output.type) }}
              >
                {output.type}
              </span>
              <span className="port-label" style={{ textAlign: 'right' }}>
                {output.name}
              </span>
              <span
                className="port-dot"
                style={{ background: getTypeColor(output.type) }}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default memo(DomainNode);
