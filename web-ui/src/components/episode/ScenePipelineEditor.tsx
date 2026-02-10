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
import { savePipeline, getVideoNodeCatalog } from '../../api/pipeline-api';
import {
  buildEpisodePipeline,
  getEpisodePipeline,
  listPipelineTemplates,
  applyPipelineTemplate,
  type PipelineTemplate,
} from '../../api/episode-api';

interface ScenePipelineEditorProps {
  episodeId: string;
  settings?: Record<string, any>;
  onPipelineReady?: (pipelineId: string) => void;
}

const nodeTypes: NodeTypes = {
  domain: DomainNode as any,
};

type SceneFilter = 'all' | 'post' | string; // string = "scene_0", "scene_1", etc.

function ScenePipelineEditorInner({ episodeId, settings, onPipelineReady }: ScenePipelineEditorProps) {
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);
  const [pipeline, setPipeline] = useState<PipelineDefinition | null>(null);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [sceneFilter, setSceneFilter] = useState<SceneFilter>('all');
  const [loading, setLoading] = useState(true);
  const [building, setBuilding] = useState(false);
  const [templates, setTemplates] = useState<PipelineTemplate[]>([]);
  const [nodeResults, setNodeResults] = useState<Record<string, any>>({});
  const [catalog, setCatalog] = useState<NodeCatalogEntry[]>([]);
  const reactFlowWrapper = useRef<HTMLDivElement>(null);
  const { fitView } = useReactFlow();

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
      const c = await getVideoNodeCatalog();
      setCatalog(c);
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
        },
      } as Node;
    });

    const rfEdges = p.edges.map((e: any) => ({
      id: e.id,
      source: e.source,
      sourceHandle: e.source_port || 'output',
      target: e.target,
      targetHandle: e.target_port || 'input',
      animated: false,
      style: { stroke: '#6366F1' },
    }));

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
    try {
      const data = await buildEpisodePipeline(episodeId, settings);
      if (data.success && data.pipeline) {
        setPipeline(data.pipeline);
        loadPipelineIntoCanvas(data.pipeline);
        onPipelineReady?.(data.pipeline_id!);
      }
    } catch (e) {
      console.error('Failed to build pipeline:', e);
    } finally {
      setBuilding(false);
    }
  };

  const handleApplyTemplate = async (templateId: string) => {
    setBuilding(true);
    try {
      const data = await applyPipelineTemplate(episodeId, templateId);
      if (data.success && data.pipeline) {
        setPipeline(data.pipeline);
        loadPipelineIntoCanvas(data.pipeline);
        onPipelineReady?.(data.pipeline_id!);
      }
    } catch (e) {
      console.error('Failed to apply template:', e);
    } finally {
      setBuilding(false);
    }
  };

  const handleSave = async () => {
    if (!pipeline) return;
    const updated: PipelineDefinition = {
      ...pipeline,
      nodes: nodes.map(n => {
        const d = n.data as any;
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
    await savePipeline(updated);
  };

  const onConnect = useCallback((connection: Connection) => {
    setEdges((eds) => addEdge({ ...connection, animated: false, style: { stroke: '#6366F1' } }, eds));
  }, [setEdges]);

  const onNodeClick = useCallback((_: any, node: Node) => {
    setSelectedNode(node);
  }, []);

  const onPaneClick = useCallback(() => {
    setSelectedNode(null);
  }, []);

  // Drag from catalog
  const onDragOver = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  const onDrop = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    const data = event.dataTransfer.getData('application/reactflow');
    if (!data) return;
    const nodeData: NodeCatalogEntry = JSON.parse(data);
    const bounds = reactFlowWrapper.current?.getBoundingClientRect();
    if (!bounds) return;

    const newNode = {
      id: `custom_${Date.now()}`,
      type: 'domain',
      position: { x: event.clientX - bounds.left, y: event.clientY - bounds.top },
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
      },
    } as Node;
    setNodes((nds) => [...nds, newNode]);
  }, [setNodes]);

  const onCatalogDragStart = useCallback((event: React.DragEvent, node: NodeCatalogEntry) => {
    event.dataTransfer.setData('application/reactflow', JSON.stringify(node));
    event.dataTransfer.effectAllowed = 'move';
  }, []);

  // Extract scene indices from node IDs
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

  // Filter nodes by scene
  const filteredNodes = useMemo(() => {
    if (sceneFilter === 'all') return nodes;
    if (sceneFilter === 'post') return nodes.filter(n => n.id.startsWith('post_'));
    // scene_X filter
    return nodes.filter(n => n.id.startsWith(`${sceneFilter}_`) || n.id.startsWith(`assembly_${sceneFilter.split('_')[1]}`));
  }, [nodes, sceneFilter]);

  const filteredEdges = useMemo(() => {
    const nodeIds = new Set(filteredNodes.map(n => n.id));
    return edges.filter(e => nodeIds.has(e.source) && nodeIds.has(e.target!));
  }, [filteredNodes, edges]);

  // Fit view when filter changes
  useEffect(() => {
    setTimeout(() => fitView({ padding: 0.2 }), 50);
  }, [sceneFilter]);

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
                      padding: '8px 16px',
                      borderRadius: 8,
                      border: '1px solid var(--border)',
                      background: 'var(--bg-surface)',
                      color: 'var(--text-primary)',
                      fontSize: '0.8125rem',
                      cursor: 'pointer',
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

  // Pipeline exists — show editor
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: 'calc(100vh - 300px)', minHeight: 500 }}>
      {/* Scene filter chips */}
      <div style={{ display: 'flex', gap: 6, padding: '8px 0', flexWrap: 'wrap', alignItems: 'center' }}>
        <button
          onClick={() => setSceneFilter('all')}
          style={{
            padding: '4px 12px', borderRadius: 14, fontSize: '0.8rem', cursor: 'pointer',
            border: sceneFilter === 'all' ? '1.5px solid var(--accent)' : '1px solid var(--border)',
            background: sceneFilter === 'all' ? 'rgba(99,102,241,0.15)' : 'transparent',
            color: sceneFilter === 'all' ? 'var(--accent)' : 'var(--text-secondary)',
          }}
        >
          All
        </button>
        {sceneIndices.map(i => (
          <button
            key={i}
            onClick={() => setSceneFilter(`scene_${i}`)}
            style={{
              padding: '4px 12px', borderRadius: 14, fontSize: '0.8rem', cursor: 'pointer',
              border: sceneFilter === `scene_${i}` ? '1.5px solid var(--accent)' : '1px solid var(--border)',
              background: sceneFilter === `scene_${i}` ? 'rgba(99,102,241,0.15)' : 'transparent',
              color: sceneFilter === `scene_${i}` ? 'var(--accent)' : 'var(--text-secondary)',
            }}
          >
            Scene {i + 1}
          </button>
        ))}
        {hasPostNodes && (
          <button
            onClick={() => setSceneFilter('post')}
            style={{
              padding: '4px 12px', borderRadius: 14, fontSize: '0.8rem', cursor: 'pointer',
              border: sceneFilter === 'post' ? '1.5px solid var(--accent)' : '1px solid var(--border)',
              background: sceneFilter === 'post' ? 'rgba(99,102,241,0.15)' : 'transparent',
              color: sceneFilter === 'post' ? 'var(--accent)' : 'var(--text-secondary)',
            }}
          >
            Post-Processing
          </button>
        )}

        <div style={{ flex: 1 }} />

        <button
          onClick={handleBuildPipeline}
          disabled={building}
          style={{
            padding: '4px 12px', borderRadius: 8, fontSize: '0.8rem', cursor: 'pointer',
            border: '1px solid var(--border)', background: 'transparent', color: 'var(--text-secondary)',
          }}
        >
          <span className="material-icons" style={{ fontSize: 14, verticalAlign: 'middle', marginRight: 4 }}>refresh</span>
          Re-generate
        </button>
        <button
          onClick={handleSave}
          style={{
            padding: '4px 12px', borderRadius: 8, fontSize: '0.8rem', cursor: 'pointer',
            border: '1px solid var(--accent)', background: 'rgba(99,102,241,0.1)', color: 'var(--accent)',
          }}
        >
          <span className="material-icons" style={{ fontSize: 14, verticalAlign: 'middle', marginRight: 4 }}>save</span>
          Save
        </button>
        {pipeline && (
          <a
            href={`/pipelines/${pipeline.id}`}
            target="_blank"
            rel="noopener noreferrer"
            style={{
              padding: '4px 12px', borderRadius: 8, fontSize: '0.8rem', cursor: 'pointer',
              border: '1px solid var(--border)', color: 'var(--text-secondary)',
              textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: 4,
            }}
          >
            Full Editor
            <span className="material-icons" style={{ fontSize: 12 }}>open_in_new</span>
          </a>
        )}
      </div>

      {/* Three-panel layout */}
      <div style={{ display: 'flex', flex: 1, border: '1px solid var(--border)', borderRadius: 12, overflow: 'hidden' }}>
        {/* Narrow catalog */}
        <div style={{ width: 160, borderRight: '1px solid var(--border)', overflow: 'auto' }}>
          <NodeCatalog onDragStart={onCatalogDragStart} />
        </div>

        {/* Canvas */}
        <div ref={reactFlowWrapper} style={{ flex: 1 }}>
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
            nodeTypes={nodeTypes}
            fitView
            minZoom={0.1}
            maxZoom={2}
            proOptions={{ hideAttribution: true }}
          >
            <Controls />
            <Background variant={BackgroundVariant.Dots} gap={16} />
            <MiniMap
              style={{ background: 'var(--bg-surface)' }}
              nodeStrokeWidth={3}
            />
          </ReactFlow>
        </div>

        {/* Config panel */}
        {selectedNode && (
          <div style={{ width: 280, borderLeft: '1px solid var(--border)', overflow: 'auto' }}>
            <NodeConfigPanel
              node={selectedNode}
              onUpdate={(nodeId, partial) => {
                setNodes(nds => nds.map(n => {
                  if (n.id === nodeId) {
                    return { ...n, data: { ...(n.data as any), ...partial } } as Node;
                  }
                  return n;
                }));
              }}
              onClose={() => setSelectedNode(null)}
            />
          </div>
        )}
      </div>
    </div>
  );
}

export default function ScenePipelineEditor(props: ScenePipelineEditorProps) {
  return (
    <ReactFlowProvider>
      <PipelineProvider
        value={{
          onPlayFromHere: () => {},
          isRunning: false,
          nodeResults: {},
        }}
      >
        <ScenePipelineEditorInner {...props} />
      </PipelineProvider>
    </ReactFlowProvider>
  );
}
