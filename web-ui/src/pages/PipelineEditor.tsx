import { useState, useCallback, useRef, useEffect, useMemo } from 'react';
import { useParams } from 'react-router-dom';
import {
  ReactFlow,
  addEdge,
  useNodesState,
  useEdgesState,
  Controls,
  MiniMap,
  Background,
  BackgroundVariant,
  type Connection,
  type Node,
  type Edge,
  type NodeTypes,
  ReactFlowProvider,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';

import DomainNode from '../components/pipeline/DomainNode';
import type { DomainNodeData } from '../components/pipeline/DomainNode';
import NodeCatalog from '../components/pipeline/NodeCatalog';
import NodeConfigPanel from '../components/pipeline/NodeConfigPanel';
import { PipelineProvider } from '../components/pipeline/PipelineContext';
import { getTypeColor } from '../components/pipeline/dataTypeColors';
import type { NodeCatalogEntry, PipelineDefinition } from '../api/pipeline-api';
import {
  savePipeline,
  getPipeline,
  runPipeline,
  runPipelineFromNode,
  listPipelines,
  deletePipeline,
  getVideoNodeCatalog,
} from '../api/pipeline-api';

import '../components/pipeline/pipeline.css';

const nodeTypes: NodeTypes = {
  domain: DomainNode as any,
};

let nodeIdCounter = 0;

function PipelineEditorInner() {
  const { id: pipelineId } = useParams<{ id: string }>();
  const reactFlowWrapper = useRef<HTMLDivElement>(null);
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [pipelineName, setPipelineName] = useState('Untitled Pipeline');
  const [pipelineDescription, setPipelineDescription] = useState('');
  const [currentPipelineId, setCurrentPipelineId] = useState(pipelineId || '');
  const [isRunning, setIsRunning] = useState(false);
  const [executionLog, setExecutionLog] = useState<string[]>([]);
  const [showPipelineList, setShowPipelineList] = useState(false);
  const [savedPipelines, setSavedPipelines] = useState<any[]>([]);
  const [nodeResults, setNodeResults] = useState<Record<string, Record<string, any>>>({});
  const [catalogCache, setCatalogCache] = useState<NodeCatalogEntry[]>([]);
  const reactFlowInstance = useRef<any>(null);

  // Load catalog for output type lookups
  useEffect(() => {
    getVideoNodeCatalog().then(setCatalogCache).catch(() => {});
  }, []);

  // Load pipeline if ID provided
  useEffect(() => {
    if (pipelineId) {
      loadPipeline(pipelineId);
    }
  }, [pipelineId]);

  const loadPipeline = async (id: string) => {
    try {
      const pipeline = await getPipeline(id);
      if (!pipeline) return;

      const catalog = catalogCache.length ? catalogCache : await getVideoNodeCatalog();

      setPipelineName(pipeline.name);
      setPipelineDescription(pipeline.description);
      setCurrentPipelineId(pipeline.id);

      const rfNodes: Node[] = pipeline.nodes.map((n) => {
        const catalogEntry = catalog.find((c) => c.type === n.type);
        return {
          id: n.id,
          type: 'domain',
          position: n.position,
          data: {
            label: n.label,
            taskType: n.type,
            domain: n.domain,
            domainName: catalogEntry?.domain_name || n.domain,
            color: catalogEntry?.color || '',
            icon: catalogEntry?.icon || '',
            description: catalogEntry?.description || '',
            params: n.params,
            inputs: catalogEntry?.inputs || [{ name: 'input', type: 'any' }],
            outputs: catalogEntry?.outputs || [{ name: 'output', type: 'any' }],
            category: catalogEntry?.category,
          } as DomainNodeData,
        };
      });

      const rfEdges: Edge[] = pipeline.edges.map((e) => {
        const sourceNode = rfNodes.find((n) => n.id === e.source);
        const sourceData = sourceNode?.data as DomainNodeData | undefined;
        const outputPort = sourceData?.outputs?.find((o) => o.name === e.source_port);
        const edgeColor = outputPort ? getTypeColor(outputPort.type) : '#6C5CE7';

        return {
          id: e.id,
          source: e.source,
          sourceHandle: e.source_port,
          target: e.target,
          targetHandle: e.target_port,
          animated: false,
          style: { stroke: edgeColor, strokeWidth: 2 },
        };
      });

      setNodes(rfNodes);
      setEdges(rfEdges);
      nodeIdCounter = rfNodes.length;
    } catch (e) {
      console.error('Failed to load pipeline:', e);
    }
  };

  const onConnect = useCallback(
    (connection: Connection) => {
      const sourceNode = nodes.find((n) => n.id === connection.source);
      const sourceData = sourceNode?.data as DomainNodeData | undefined;
      const outputPort = sourceData?.outputs?.find(
        (o) => o.name === connection.sourceHandle
      );
      const edgeColor = outputPort ? getTypeColor(outputPort.type) : '#6C5CE7';

      setEdges((eds) =>
        addEdge(
          {
            ...connection,
            animated: false,
            style: { stroke: edgeColor, strokeWidth: 2 },
          },
          eds
        )
      );
    },
    [setEdges, nodes]
  );

  const onNodeClick = useCallback((_: any, node: Node) => {
    setSelectedNode(node);
  }, []);

  const onPaneClick = useCallback(() => {
    setSelectedNode(null);
  }, []);

  const onDragStart = useCallback((event: React.DragEvent, catalogNode: NodeCatalogEntry) => {
    event.dataTransfer.setData('application/json', JSON.stringify(catalogNode));
    event.dataTransfer.effectAllowed = 'move';
  }, []);

  const onDragOver = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  const onDrop = useCallback(
    (event: React.DragEvent) => {
      event.preventDefault();

      const data = event.dataTransfer.getData('application/json');
      if (!data) return;

      const catalogNode: NodeCatalogEntry = JSON.parse(data);
      const bounds = reactFlowWrapper.current?.getBoundingClientRect();
      if (!bounds || !reactFlowInstance.current) return;

      const position = reactFlowInstance.current.screenToFlowPosition({
        x: event.clientX - bounds.left,
        y: event.clientY - bounds.top,
      });

      const newNode: Node = {
        id: `node_${++nodeIdCounter}`,
        type: 'domain',
        position,
        data: {
          label: catalogNode.name,
          taskType: catalogNode.type,
          domain: catalogNode.domain,
          domainName: catalogNode.domain_name,
          color: catalogNode.color,
          icon: catalogNode.icon,
          description: catalogNode.description,
          params: {},
          inputs: catalogNode.inputs,
          outputs: catalogNode.outputs,
          category: catalogNode.category,
          status: undefined,
        } as DomainNodeData,
      };

      setNodes((nds) => [...nds, newNode]);
    },
    [setNodes]
  );

  const onUpdateNode = useCallback(
    (nodeId: string, dataUpdate: Partial<DomainNodeData>) => {
      setNodes((nds) =>
        nds.map((n) =>
          n.id === nodeId
            ? { ...n, data: { ...n.data, ...dataUpdate } }
            : n
        )
      );
      setSelectedNode((prev) =>
        prev && prev.id === nodeId
          ? { ...prev, data: { ...prev.data, ...dataUpdate } }
          : prev
      );
    },
    [setNodes]
  );

  // Save pipeline
  const handleSave = async (): Promise<string | null> => {
    const pipelineNodes = nodes.map((n) => {
      const d = n.data as DomainNodeData;
      return {
        id: n.id,
        type: d.taskType,
        domain: d.domain,
        label: d.label,
        position: n.position,
        params: d.params,
      };
    });

    const pipelineEdges = edges.map((e) => ({
      id: e.id,
      source: e.source,
      source_port: e.sourceHandle || 'output',
      target: e.target,
      target_port: e.targetHandle || 'input',
    }));

    try {
      const saved = await savePipeline({
        id: currentPipelineId || undefined,
        name: pipelineName,
        description: pipelineDescription,
        nodes: pipelineNodes,
        edges: pipelineEdges,
        parameters: [],
      });
      setCurrentPipelineId(saved.id);
      addLog(`Pipeline saved: ${saved.id}`);
      return saved.id;
    } catch (e) {
      addLog(`Save failed: ${e}`);
      return null;
    }
  };

  // Connect WS and run pipeline
  const connectAndRun = useCallback(
    async (pipelineId: string, fromNodeId?: string) => {
      setIsRunning(true);
      setExecutionLog([]);
      addLog(fromNodeId ? `Running from node ${fromNodeId}...` : 'Starting pipeline execution...');

      setNodes((nds) =>
        nds.map((n) => ({
          ...n,
          data: { ...n.data, status: 'pending', result: undefined, error: undefined },
        }))
      );

      setEdges((eds) => eds.map((e) => ({ ...e, animated: true })));

      try {
        const ws = new WebSocket('ws://localhost:9876');
        let authenticated = false;

        ws.onopen = async () => {
          const timestamp = Date.now();
          const input = `web_pipeline:${timestamp}:opencli-dev-secret`;
          const encoder = new TextEncoder();
          const hashBuffer = await crypto.subtle.digest('SHA-256', encoder.encode(input));
          const hashArray = Array.from(new Uint8Array(hashBuffer));
          const token = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');

          ws.send(
            JSON.stringify({
              type: 'auth',
              device_id: 'web_pipeline',
              token,
              timestamp,
            })
          );
        };

        ws.onmessage = async (event) => {
          try {
            const msg = JSON.parse(event.data);

            if (msg.type === 'auth_success' && !authenticated) {
              authenticated = true;
              addLog('Connected to daemon');

              let result;
              if (fromNodeId) {
                result = await runPipelineFromNode(pipelineId, fromNodeId, {}, nodeResults);
              } else {
                result = await runPipeline(pipelineId);
              }

              if (!result.success) {
                addLog(`Execution failed: ${result.error}`);
                setIsRunning(false);
                setEdges((eds) => eds.map((e) => ({ ...e, animated: false })));
                ws.close();
              }
              return;
            }

            if (msg.type === 'task_update' && msg.task_type === 'pipeline_execute') {
              const result = msg.result || {};

              if (result.node_status) {
                setNodes((nds) =>
                  nds.map((n) => ({
                    ...n,
                    data: {
                      ...n.data,
                      status: result.node_status[n.id] || 'pending',
                      result: result.node_results?.[n.id],
                      error: result.node_results?.[n.id]?.error,
                    },
                  }))
                );
              }

              if (result.node_results) {
                setNodeResults((prev) => ({ ...prev, ...result.node_results }));
              }

              if (result.current_node) {
                addLog(
                  `Node ${result.current_node}: ${result.node_status?.[result.current_node] || 'running'}`
                );
              }

              if (msg.status === 'completed' || msg.status === 'failed') {
                setIsRunning(false);
                setEdges((eds) => eds.map((e) => ({ ...e, animated: false })));
                addLog(`Pipeline ${msg.status}. Duration: ${result.duration_ms || 0}ms`);
                ws.close();
              }
            }
          } catch (e) {
            // ignore parse errors
          }
        };

        ws.onerror = () => {
          addLog('WebSocket connection error');
          setIsRunning(false);
          setEdges((eds) => eds.map((e) => ({ ...e, animated: false })));
        };
      } catch (e) {
        addLog(`Error: ${e}`);
        setIsRunning(false);
        setEdges((eds) => eds.map((e) => ({ ...e, animated: false })));
      }
    },
    [setNodes, setEdges, nodeResults]
  );

  const handleRun = async () => {
    let id = currentPipelineId;
    if (!id) {
      const savedId = await handleSave();
      if (!savedId) {
        addLog('Save pipeline first');
        return;
      }
      id = savedId;
    }
    connectAndRun(id);
  };

  const handlePlayFromHere = useCallback(
    async (nodeId: string) => {
      let id = currentPipelineId;
      if (!id) {
        const savedId = await handleSave();
        if (!savedId) {
          addLog('Save pipeline first');
          return;
        }
        id = savedId;
      }
      connectAndRun(id, nodeId);
    },
    [currentPipelineId, connectAndRun]
  );

  const handleNew = () => {
    setNodes([]);
    setEdges([]);
    setPipelineName('Untitled Pipeline');
    setPipelineDescription('');
    setCurrentPipelineId('');
    setSelectedNode(null);
    setExecutionLog([]);
    setNodeResults({});
    nodeIdCounter = 0;
  };

  const handleShowList = async () => {
    try {
      const pipelines = await listPipelines();
      setSavedPipelines(pipelines);
      setShowPipelineList(true);
    } catch (e) {
      addLog(`Failed to load pipelines: ${e}`);
    }
  };

  const handleDeletePipeline = async (id: string) => {
    await deletePipeline(id);
    const pipelines = await listPipelines();
    setSavedPipelines(pipelines);
  };

  const addLog = (message: string) => {
    const time = new Date().toLocaleTimeString('en-US', { hour12: false });
    setExecutionLog((prev) => [...prev, `[${time}] ${message}`]);
  };

  const pipelineContextValue = useMemo(
    () => ({
      onPlayFromHere: handlePlayFromHere,
      isRunning,
      nodeResults,
    }),
    [handlePlayFromHere, isRunning, nodeResults]
  );

  return (
    <PipelineProvider value={pipelineContextValue}>
      <div className="pipeline-page">
        {/* Top toolbar */}
        <div className="pipeline-toolbar">
          <input
            type="text"
            className="toolbar-name"
            value={pipelineName}
            onChange={(e) => setPipelineName(e.target.value)}
            placeholder="Pipeline name..."
          />

          <div className="toolbar-actions">
            <button className="toolbar-btn" onClick={handleNew}>New</button>
            <button className="toolbar-btn" onClick={handleShowList}>Open</button>
            <button className="toolbar-btn primary" onClick={handleSave}>Save</button>
          </div>
        </div>

        <div className="pipeline-main">
          {/* Left: Node Catalog */}
          <NodeCatalog onDragStart={onDragStart} />

          {/* Center: React Flow Canvas */}
          <div className="pipeline-canvas" ref={reactFlowWrapper}>
            <ReactFlow
              nodes={nodes}
              edges={edges}
              onNodesChange={onNodesChange}
              onEdgesChange={onEdgesChange}
              onConnect={onConnect}
              onNodeClick={onNodeClick}
              onPaneClick={onPaneClick}
              onDragOver={onDragOver}
              onDrop={onDrop}
              onInit={(instance) => {
                reactFlowInstance.current = instance;
              }}
              nodeTypes={nodeTypes}
              fitView
              proOptions={{ hideAttribution: true }}
              defaultEdgeOptions={{
                style: { stroke: '#6C5CE7', strokeWidth: 2 },
                type: 'default',
              }}
            >
              <Background variant={BackgroundVariant.Dots} gap={20} size={1} color="#333333" />
              <Controls />
              <MiniMap
                nodeColor={(n) => {
                  const d = n.data as DomainNodeData;
                  if (d.status === 'completed') return '#16A34A';
                  if (d.status === 'failed') return '#EF4444';
                  if (d.status === 'running') return '#6C5CE7';
                  return '#444444';
                }}
                style={{ background: '#141414', border: '1px solid #2a2a2a' }}
              />
            </ReactFlow>

            {/* Empty state */}
            {nodes.length === 0 && (
              <div className="canvas-empty">
                Drag nodes from the catalog to start building your video pipeline
              </div>
            )}

            {/* Run pipeline FAB */}
            <button
              className={`run-pipeline-fab${isRunning ? ' running' : ''}`}
              onClick={handleRun}
              disabled={isRunning || nodes.length === 0}
            >
              {isRunning ? 'Running...' : 'Run pipeline'}
            </button>
          </div>

          {/* Right: Config Panel */}
          <NodeConfigPanel
            node={selectedNode}
            onUpdate={onUpdateNode}
            onClose={() => setSelectedNode(null)}
          />
        </div>

        {/* Bottom: Execution Log */}
        {executionLog.length > 0 && (
          <div className="execution-log">
            <div className="log-header">
              <span>Execution Log</span>
              <button className="log-clear" onClick={() => setExecutionLog([])}>Clear</button>
            </div>
            <div className="log-content">
              {executionLog.map((line, i) => (
                <div key={i} className="log-line">{line}</div>
              ))}
            </div>
          </div>
        )}

        {/* Pipeline list modal */}
        {showPipelineList && (
          <div className="pipeline-modal-overlay" onClick={() => setShowPipelineList(false)}>
            <div className="pipeline-modal" onClick={(e) => e.stopPropagation()}>
              <div className="modal-header">
                <span>Saved Pipelines</span>
                <button className="modal-close" onClick={() => setShowPipelineList(false)}>&times;</button>
              </div>
              <div className="modal-body">
                {savedPipelines.length === 0 ? (
                  <div className="modal-empty">No saved pipelines</div>
                ) : (
                  savedPipelines.map((p) => (
                    <div key={p.id} className="pipeline-list-item">
                      <div className="pipeline-list-info">
                        <div className="pipeline-list-name">{p.name}</div>
                        <div className="pipeline-list-meta">
                          {p.node_count} nodes | {new Date(p.updated_at).toLocaleDateString()}
                        </div>
                      </div>
                      <div className="pipeline-list-actions">
                        <button
                          className="toolbar-btn"
                          onClick={() => {
                            loadPipeline(p.id);
                            setShowPipelineList(false);
                          }}
                        >
                          Open
                        </button>
                        <button
                          className="toolbar-btn danger"
                          onClick={() => handleDeletePipeline(p.id)}
                        >
                          Del
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </PipelineProvider>
  );
}

export default function PipelineEditor() {
  return (
    <ReactFlowProvider>
      <PipelineEditorInner />
    </ReactFlowProvider>
  );
}
