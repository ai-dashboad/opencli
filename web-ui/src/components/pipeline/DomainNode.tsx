import { memo, useCallback, useState } from 'react';
import { Handle, Position, useReactFlow, type NodeProps } from '@xyflow/react';
import type { NodeInputPort, NodeOutputPort } from '../../api/pipeline-api';
import { getTypeColor, getNodeIcon } from './dataTypeColors';
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
  category?: string;
  status?: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  result?: Record<string, any>;
  error?: string;
}

function DomainNode({ id, data, selected }: NodeProps & { data: DomainNodeData }) {
  const nodeData = data as DomainNodeData;
  const { setNodes } = useReactFlow();
  const { onPlayFromHere, isRunning } = usePipelineContext();
  const [showMenu, setShowMenu] = useState(false);

  const borderColor = selected
    ? '#6C5CE7'
    : nodeData.status === 'running'
    ? '#6C5CE7'
    : nodeData.status === 'completed'
    ? '#16A34A'
    : nodeData.status === 'failed'
    ? '#EF4444'
    : '#2a2a2a';

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

  const inputs = nodeData.inputs || [];
  const outputs = nodeData.outputs || [];
  const icon = getNodeIcon(nodeData.taskType);

  return (
    <div
      className={`domain-node-v2${selected ? ' selected' : ''}${nodeData.status ? ` status-${nodeData.status}` : ''}`}
      style={{ borderColor }}
    >
      {/* Input handles (left side, small and subtle) */}
      {inputs.map((input, i) => (
        <Handle
          key={`in-${input.name}`}
          type="target"
          position={Position.Left}
          id={input.name}
          className="node-handle node-handle-input"
          style={{
            top: `${56 + i * 44}px`,
            background: getTypeColor(input.type),
          }}
        />
      ))}

      {/* Node content area */}
      <div className="node-content">
        {/* Title row */}
        <div className="node-title-row">
          <span className="node-icon">{icon}</span>
          <span className="node-title">{nodeData.label || nodeData.taskType}</span>
        </div>

        {/* Input controls */}
        <div className="node-controls">
          {inputs.map((input) => (
            <div key={input.name} className="node-control-row">
              <label className="node-control-label">{input.name}</label>
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
      </div>

      {/* Output ports (bottom section, right-aligned) */}
      {outputs.length > 0 && (
        <div className="node-outputs">
          {outputs.map((output, i) => (
            <div key={output.name} className="node-output-row">
              <span className="node-output-label">{output.name}</span>
              <span
                className="node-output-dot"
                style={{ background: getTypeColor(output.type) }}
              />
              <Handle
                key={`out-${output.name}`}
                type="source"
                position={Position.Right}
                id={output.name}
                className="node-handle node-handle-output"
                style={{
                  background: getTypeColor(output.type),
                }}
              />
            </div>
          ))}
        </div>
      )}

      {/* Footer: Play from here + menu */}
      <div className="node-footer">
        <button
          className="node-play-btn nodrag nopan"
          onClick={handlePlay}
          disabled={isRunning}
        >
          <span className="play-icon">&#9654;</span>
          Play from here
        </button>
        <div className="node-menu-wrapper">
          <button
            className="node-menu-btn nodrag nopan"
            onClick={(e) => {
              e.stopPropagation();
              setShowMenu(!showMenu);
            }}
          >
            &#8942;
          </button>
          {showMenu && (
            <div className="node-menu-dropdown nodrag nopan">
              <button
                className="node-menu-item"
                onClick={(e) => {
                  e.stopPropagation();
                  setNodes((nds) => nds.filter((n) => n.id !== id));
                  setShowMenu(false);
                }}
              >
                Delete node
              </button>
              <button
                className="node-menu-item"
                onClick={(e) => {
                  e.stopPropagation();
                  setNodes((nds) =>
                    nds.map((n) =>
                      n.id === id
                        ? {
                            ...n,
                            data: {
                              ...n.data,
                              params: {},
                              status: undefined,
                              result: undefined,
                              error: undefined,
                            },
                          }
                        : n
                    )
                  );
                  setShowMenu(false);
                }}
              >
                Reset node
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default memo(DomainNode);
