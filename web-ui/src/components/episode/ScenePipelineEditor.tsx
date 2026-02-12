import { useState, useCallback, useEffect, useMemo, useRef } from 'react';
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
  useReactFlow,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';

import DomainNode from '../pipeline/DomainNode';
import type { DomainNodeData } from '../pipeline/DomainNode';
import NodeCatalog from '../pipeline/NodeCatalog';
import NodeConfigPanel from '../pipeline/NodeConfigPanel';
import { PipelineProvider } from '../pipeline/PipelineContext';
import { getTypeColor } from '../pipeline/dataTypeColors';
import type { NodeCatalogEntry, PipelineDefinition } from '../../api/pipeline-api';
import { savePipeline, getVideoNodeCatalog, getNodeCatalog, runPipeline, runPipelineFromNode } from '../../api/pipeline-api';
import {
  buildEpisodePipeline,
  getEpisodePipeline,
  listPipelineTemplates,
  applyPipelineTemplate,
  type PipelineTemplate,
} from '../../api/episode-api';
import '../pipeline/pipeline.css';

interface ScenePipelineEditorProps {
  episodeId: string;
  settings?: Record<string, any>;
  onPipelineReady?: (pipelineId: string) => void;
}

const nodeTypes: NodeTypes = {
  domain: DomainNode as any,
};

type SceneFilter = 'all' | 'post' | string;

function ScenePipelineEditorInner({ episodeId, settings, onPipelineReady }: ScenePipelineEditorProps) {
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);
  const [pipeline, setPipeline] = useState<PipelineDefinition | null>(null);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [sceneFilter, setSceneFilter] = useState<SceneFilter>('all');
  const [loading, setLoading] = useState(true);
  const [building, setBuilding] = useState(false);
  const [templates, setTemplates] = useState<PipelineTemplate[]>([]);
  const [catalog, setCatalog] = useState<NodeCatalogEntry[]>([]);
  const [error, setError] = useState<string | null>(null);

  // Execution state — matches PipelineEditor
  const [isRunning, setIsRunning] = useState(false);
  const [executionLog, setExecutionLog] = useState<string[]>([]);
  const [nodeResults, setNodeResults] = useState<Record<string, Record<string, any>>>({});

  const reactFlowWrapper = useRef<HTMLDivElement>(null);
  const reactFlowInstance = useRef<any>(null);
  const { fitView } = useReactFlow();

  const addLog = (message: string) => {
    const time = new Date().toLocaleTimeString('en-US', { hour12: false });
    setExecutionLog((prev) => [...prev, `[${time}] ${message}`]);
  };

  // Load pipeline + templates on mount
  useEffect(() => {
    loadPipeline();
    loadTemplates();
    loadCatalog();
  }, [episodeId]);

  const loadPipeline = async () => {
    try {
      const data = await getEpisodePipeline(episodeId);
      if (data.success && data.pipeline) {
        setPipeline(data.pipeline);
        loadPipelineIntoCanvas(data.pipeline);
      }
    } catch (e) {
      console.error('Failed to load episode pipeline:', e);
    } finally {
      setLoading(false);
    }
  };

  const loadTemplates = async () => {
    try {
      const t = await listPipelineTemplates();
      setTemplates(t);
    } catch { }
  };

  const loadCatalog = async () => {
    try {
      const [videoCatalog, domainCatalog] = await Promise.all([
        getVideoNodeCatalog(),
        getNodeCatalog(),
      ]);
      // Merge: video catalog takes priority, domain catalog fills gaps
      const merged = new Map<string, NodeCatalogEntry>();
      for (const entry of domainCatalog) merged.set(entry.type, entry);
      for (const entry of videoCatalog) merged.set(entry.type, entry);
      setCatalog(Array.from(merged.values()));
    } catch { }
  };

  const loadPipelineIntoCanvas = (p: PipelineDefinition) => {
    const catalogMap: Record<string, NodeCatalogEntry> = {};
    catalog.forEach(c => { catalogMap[c.type] = c; });

    const rfNodes = p.nodes.map((n: any) => {
      const cat = catalogMap[n.type];
      return {
        id: n.id,
        type: 'domain',
        position: n.position || { x: 0, y: 0 },
        data: {
          label: n.label || n.id,
          taskType: n.type,
          domain: n.domain || '',
          domainName: cat?.domain_name || n.domain || '',
          color: cat?.color || '#6B7280',
          icon: cat?.icon || 'settings',
          description: cat?.description || '',
          params: n.params || {},
          inputs: cat?.inputs || [],
          outputs: cat?.outputs || [{ name: 'output', type: 'any' }],
          category: cat?.category,
          status: undefined,
          result: undefined,
        } as DomainNodeData,
      } as Node;
    });

    const rfEdges = p.edges.map((e: any) => {
      const sourceNode = rfNodes.find(n => n.id === e.source);
      const sourceData = sourceNode?.data as DomainNodeData | undefined;
      const outputPort = sourceData?.outputs?.find((o) => o.name === (e.source_port || 'output'));
      const edgeColor = outputPort ? getTypeColor(outputPort.type) : '#6C5CE7';
      return {
        id: e.id,
        source: e.source,
        sourceHandle: e.source_port || 'output',
        target: e.target,
        targetHandle: e.target_port || 'input',
        animated: false,
        style: { stroke: edgeColor, strokeWidth: 2 },
      };
    });

    setNodes(rfNodes);
    setEdges(rfEdges);
    setTimeout(() => fitView({ padding: 0.2 }), 100);
  };

  // Rebuild canvas when catalog loads after pipeline
  useEffect(() => {
    if (pipeline && catalog.length > 0) {
      loadPipelineIntoCanvas(pipeline);
    }
  }, [catalog]);

  const handleBuildPipeline = async () => {
    setBuilding(true);
    setError(null);
    try {
      const data = await buildEpisodePipeline(episodeId, settings);
      if (data.success && data.pipeline) {
        setPipeline(data.pipeline);
        loadPipelineIntoCanvas(data.pipeline);
        onPipelineReady?.(data.pipeline_id!);
      } else {
        setError((data as any).error || 'Failed to build pipeline');
      }
    } catch (e: any) {
      setError(e.message || 'Network error — is the daemon running?');
    } finally {
      setBuilding(false);
    }
  };

  const handleApplyTemplate = async (templateId: string) => {
    setBuilding(true);
    setError(null);
    try {
      const data = await applyPipelineTemplate(episodeId, templateId);
      if (data.success && data.pipeline) {
        setPipeline(data.pipeline);
        loadPipelineIntoCanvas(data.pipeline);
        onPipelineReady?.(data.pipeline_id!);
      } else {
        setError((data as any).error || 'Failed to apply template');
      }
    } catch (e: any) {
      setError(e.message || 'Network error — is the daemon running?');
    } finally {
      setBuilding(false);
    }
  };

  const handleSave = async (): Promise<string | null> => {
    if (!pipeline) return null;
    const updated: PipelineDefinition = {
      ...pipeline,
      nodes: nodes.map(n => {
        const d = n.data as DomainNodeData;
        return {
          id: n.id,
          type: d.taskType,
          domain: d.domain,
          label: d.label,
          position: n.position,
          params: d.params,
        };
      }),
      edges: edges.map(e => ({
        id: e.id,
        source: e.source,
        source_port: e.sourceHandle || 'output',
        target: e.target!,
        target_port: e.targetHandle || 'input',
      })),
    };
    try {
      const saved = await savePipeline(updated);
      addLog(`Pipeline saved: ${saved.id}`);
      return saved.id;
    } catch (e) {
      addLog(`Save failed: ${e}`);
      return null;
    }
  };

  // ── WS Execution (matches PipelineEditor) ──────────────────────────
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

          ws.send(JSON.stringify({
            type: 'auth',
            device_id: 'web_pipeline',
            token,
            timestamp,
          }));
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
              } else {
                if (result.node_statuses) {
                  setNodes((nds) =>
                    nds.map((n) => ({
                      ...n,
                      data: {
                        ...n.data,
                        status: result.node_statuses[n.id] || 'pending',
                        result: result.node_results?.[n.id],
                        error: result.node_results?.[n.id]?.error,
                      },
                    }))
                  );
                }
                if (result.node_results) {
                  setNodeResults((prev) => ({ ...prev, ...result.node_results }));
                }
                addLog(`Pipeline completed. Duration: ${result.duration_ms || 0}ms`);
              }
              setIsRunning(false);
              setEdges((eds) => eds.map((e) => ({ ...e, animated: false })));
              ws.close();
              return;
            }

            if (msg.type === 'task_update' && msg.task_type === 'pipeline_execute') {
              const result = msg.result || {};

              // Real-time per-node status updates (from on_progress callback)
              const statuses = result.node_status || result.all_statuses;
              if (statuses) {
                const currentNodeId = result.current_node || '';
                const nodeResult = result.node_result;

                setNodes((nds) =>
                  nds.map((n) => {
                    const nodeStatus = statuses[n.id] || n.data.status || 'pending';
                    const updatedResult =
                      n.id === currentNodeId && nodeResult
                        ? nodeResult
                        : result.node_results?.[n.id] || (n.data as any).result;
                    return {
                      ...n,
                      data: {
                        ...n.data,
                        status: nodeStatus,
                        result: updatedResult,
                        error: updatedResult?.error,
                      },
                    };
                  })
                );

                if (currentNodeId && nodeResult) {
                  setNodeResults((prev) => ({ ...prev, [currentNodeId]: nodeResult }));
                }
              }

              if (result.node_results) {
                setNodeResults((prev) => ({ ...prev, ...result.node_results }));
              }

              if (result.current_node) {
                const nodeStatus = (statuses || {})[result.current_node] || 'running';
                addLog(`Node ${result.current_node}: ${nodeStatus}`);
              }

              if (msg.status === 'completed' || msg.status === 'failed') {
                setIsRunning(false);
                setEdges((eds) => eds.map((e) => ({ ...e, animated: false })));
                addLog(`Pipeline ${msg.status}. Duration: ${result.duration_ms || 0}ms`);
                ws.close();
              }
            }
          } catch {
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
    if (!pipeline) return;
    let id = pipeline.id;
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
      if (!pipeline) return;
      let id = pipeline.id;
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
    [pipeline, connectAndRun]
  );

  // ── Canvas interactions ────────────────────────────────────────────

  const onConnect = useCallback((connection: Connection) => {
    const sourceNode = nodes.find((n) => n.id === connection.source);
    const sourceData = sourceNode?.data as DomainNodeData | undefined;
    const outputPort = sourceData?.outputs?.find((o) => o.name === connection.sourceHandle);
    const edgeColor = outputPort ? getTypeColor(outputPort.type) : '#6C5CE7';

    setEdges((eds) =>
      addEdge({ ...connection, animated: false, style: { stroke: edgeColor, strokeWidth: 2 } }, eds)
    );
  }, [setEdges, nodes]);

  const onNodeClick = useCallback((_: any, node: Node) => {
    setSelectedNode(node);
  }, []);

  const onPaneClick = useCallback(() => {
    setSelectedNode(null);
  }, []);

  const onUpdateNode = useCallback(
    (nodeId: string, dataUpdate: Partial<DomainNodeData>) => {
      setNodes((nds) =>
        nds.map((n) => (n.id === nodeId ? { ...n, data: { ...n.data, ...dataUpdate } } : n))
      );
      setSelectedNode((prev) =>
        prev && prev.id === nodeId ? { ...prev, data: { ...prev.data, ...dataUpdate } } : prev
      );
    },
    [setNodes]
  );

  // Drag from catalog — use application/json (matching PipelineEditor)
  const onDragOver = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  const onDrop = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    const data = event.dataTransfer.getData('application/json');
    if (!data) return;
    const nodeData: NodeCatalogEntry = JSON.parse(data);
    const bounds = reactFlowWrapper.current?.getBoundingClientRect();
    if (!bounds || !reactFlowInstance.current) return;

    const position = reactFlowInstance.current.screenToFlowPosition({
      x: event.clientX - bounds.left,
      y: event.clientY - bounds.top,
    });

    const newNode = {
      id: `custom_${Date.now()}`,
      type: 'domain',
      position,
      data: {
        label: nodeData.name,
        taskType: nodeData.type,
        domain: nodeData.domain,
        domainName: nodeData.domain_name,
        color: nodeData.color,
        icon: nodeData.icon,
        description: nodeData.description,
        params: {},
        inputs: nodeData.inputs,
        outputs: nodeData.outputs,
        category: nodeData.category,
        status: undefined,
      } as DomainNodeData,
    } as Node;
    setNodes((nds) => [...nds, newNode]);
  }, [setNodes]);

  const onCatalogDragStart = useCallback((event: React.DragEvent, node: NodeCatalogEntry) => {
    event.dataTransfer.setData('application/json', JSON.stringify(node));
    event.dataTransfer.effectAllowed = 'move';
  }, []);

  // ── Scene filtering ────────────────────────────────────────────────

  const sceneIndices = useMemo(() => {
    const indices = new Set<number>();
    nodes.forEach(n => {
      const match = n.id.match(/^scene_(\d+)_/);
      if (match) indices.add(parseInt(match[1]));
    });
    return Array.from(indices).sort();
  }, [nodes]);

  const hasPostNodes = useMemo(() => {
    return nodes.some(n => n.id.startsWith('post_'));
  }, [nodes]);

  const filteredNodes = useMemo(() => {
    if (sceneFilter === 'all') return nodes;
    if (sceneFilter === 'post') return nodes.filter(n => n.id.startsWith('post_'));
    return nodes.filter(n => n.id.startsWith(`${sceneFilter}_`) || n.id.startsWith(`assembly_${sceneFilter.split('_')[1]}`));
  }, [nodes, sceneFilter]);

  const filteredEdges = useMemo(() => {
    const nodeIds = new Set(filteredNodes.map(n => n.id));
    return edges.filter(e => nodeIds.has(e.source) && nodeIds.has(e.target!));
  }, [filteredNodes, edges]);

  useEffect(() => {
    setTimeout(() => fitView({ padding: 0.2 }), 50);
  }, [sceneFilter]);

  // ── PipelineProvider value ─────────────────────────────────────────

  const pipelineContextValue = useMemo(
    () => ({
      onPlayFromHere: handlePlayFromHere,
      isRunning,
      nodeResults,
    }),
    [handlePlayFromHere, isRunning, nodeResults]
  );

  // ── Render ─────────────────────────────────────────────────────────

  if (loading) {
    return <div style={{ padding: 20, color: 'var(--text-secondary)' }}>Loading pipeline...</div>;
  }

  // No pipeline yet — show build/template UI
  if (!pipeline) {
    return (
      <div style={{ padding: 20 }}>
        <div style={{ textAlign: 'center', padding: '40px 20px' }}>
          <span className="material-icons" style={{ fontSize: 48, color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>
            account_tree
          </span>
          <h3 style={{ margin: '0 0 8px 0' }}>No Pipeline Generated</h3>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginBottom: 20 }}>
            Generate a visual pipeline from your episode script, or apply a preset template.
          </p>
          <button
            className="gen-button"
            onClick={handleBuildPipeline}
            disabled={building}
            style={{ margin: '0 auto 16px' }}
          >
            <span className="material-icons" style={{ fontSize: 20 }}>auto_fix_high</span>
            {building ? 'Building...' : 'Auto-Generate Pipeline'}
          </button>

          {error && (
            <div style={{
              margin: '12px auto', padding: '8px 14px', maxWidth: 400, borderRadius: 8,
              background: 'rgba(255,82,82,0.1)', color: '#ff5252', fontSize: '0.85rem',
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
              <span className="material-icons" style={{ fontSize: 16 }}>error</span>
              {error}
            </div>
          )}

          {templates.length > 0 && (
            <div style={{ marginTop: 16 }}>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem', marginBottom: 8 }}>Or apply a template:</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center' }}>
                {templates.map(t => (
                  <button
                    key={t.id}
                    onClick={() => handleApplyTemplate(t.id)}
                    disabled={building}
                    style={{
                      padding: '8px 16px', borderRadius: 8,
                      border: '1px solid var(--border)', background: 'var(--bg-surface)',
                      color: 'var(--text-primary)', fontSize: '0.8125rem', cursor: 'pointer',
                    }}
                  >
                    {t.name}
                    <span style={{ fontSize: '0.7rem', color: 'var(--text-secondary)', marginLeft: 6 }}>
                      ({t.node_count} nodes)
                    </span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    );
  }

  // Pipeline exists — show editor with SAME layout as /pipelines
  return (
    <PipelineProvider value={pipelineContextValue}>
      <div className="pipeline-page embedded">
        {/* Scene filter chips toolbar */}
        <div className="pipeline-toolbar">
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center', flex: 1 }}>
            <button
              className={`toolbar-btn${sceneFilter === 'all' ? ' primary' : ''}`}
              onClick={() => setSceneFilter('all')}
              style={{ padding: '4px 12px', fontSize: '0.8rem' }}
            >
              All
            </button>
            {sceneIndices.map(i => (
              <button
                key={i}
                className={`toolbar-btn${sceneFilter === `scene_${i}` ? ' primary' : ''}`}
                onClick={() => setSceneFilter(`scene_${i}`)}
                style={{ padding: '4px 12px', fontSize: '0.8rem' }}
              >
                Scene {i + 1}
              </button>
            ))}
            {hasPostNodes && (
              <button
                className={`toolbar-btn${sceneFilter === 'post' ? ' primary' : ''}`}
                onClick={() => setSceneFilter('post')}
                style={{ padding: '4px 12px', fontSize: '0.8rem' }}
              >
                Post
              </button>
            )}
          </div>

          <div className="toolbar-actions">
            <button className="toolbar-btn" onClick={handleBuildPipeline} disabled={building}>
              <span className="material-icons" style={{ fontSize: 14, verticalAlign: 'middle', marginRight: 4 }}>refresh</span>
              Re-generate
            </button>
            <button className="toolbar-btn primary" onClick={() => handleSave()}>
              <span className="material-icons" style={{ fontSize: 14, verticalAlign: 'middle', marginRight: 4 }}>save</span>
              Save
            </button>
            {pipeline && (
              <a
                href={`/pipelines/${pipeline.id}`}
                target="_blank"
                rel="noopener noreferrer"
                className="toolbar-btn"
                style={{ textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: 4 }}
              >
                Full Editor
                <span className="material-icons" style={{ fontSize: 12 }}>open_in_new</span>
              </a>
            )}
          </div>
        </div>

        {/* Three-panel layout — identical to PipelineEditor */}
        <div className="pipeline-main">
          {/* Left: Node Catalog (standard 200px) */}
          <NodeCatalog onDragStart={onCatalogDragStart} />

          {/* Center: React Flow Canvas */}
          <div className="pipeline-canvas" ref={reactFlowWrapper}>
            <ReactFlow
              nodes={filteredNodes}
              edges={filteredEdges}
              onNodesChange={onNodesChange}
              onEdgesChange={onEdgesChange}
              onConnect={onConnect}
              onNodeClick={onNodeClick}
              onPaneClick={onPaneClick}
              onDrop={onDrop}
              onDragOver={onDragOver}
              onInit={(instance) => { reactFlowInstance.current = instance; }}
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
                <span className="material-icons" style={{ fontSize: 48, opacity: 0.3, marginBottom: 12 }}>account_tree</span>
                <div style={{ fontSize: '1.1rem', marginBottom: 6 }}>No nodes yet</div>
                <div style={{ fontSize: '0.85rem', opacity: 0.5 }}>Drag nodes from the catalog on the left to build your pipeline</div>
              </div>
            )}

            {/* Run pipeline FAB — identical to PipelineEditor */}
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

        {/* Bottom: Execution Log — identical to PipelineEditor */}
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
      </div>
    </PipelineProvider>
  );
}

export default function ScenePipelineEditor(props: ScenePipelineEditorProps) {
  return (
    <ReactFlowProvider>
      <ScenePipelineEditorInner {...props} />
    </ReactFlowProvider>
  );
}
