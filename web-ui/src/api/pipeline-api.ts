const API_BASE = 'http://localhost:9529/api/v1';

export interface PipelineNode {
  id: string;
  type: string;
  domain: string;
  label: string;
  position: { x: number; y: number };
  params: Record<string, any>;
}

export interface PipelineEdge {
  id: string;
  source: string;
  source_port: string;
  target: string;
  target_port: string;
}

export interface PipelineDefinition {
  id: string;
  name: string;
  description: string;
  nodes: PipelineNode[];
  edges: PipelineEdge[];
  parameters: { name: string; type: string; default: any; description: string }[];
  created_at: string;
  updated_at: string;
}

export interface PipelineSummary {
  id: string;
  name: string;
  description: string;
  node_count: number;
  edge_count: number;
  created_at: string;
  updated_at: string;
}

export interface NodeInputPort {
  name: string;
  type: string;
  description?: string;
  required?: boolean;
  inputType?: 'text' | 'textarea' | 'select' | 'slider' | 'file' | 'toggle';
  options?: string[];
  defaultValue?: any;
  min?: number;
  max?: number;
  step?: number;
}

export interface NodeOutputPort {
  name: string;
  type: string;
}

export interface NodeCatalogEntry {
  type: string;
  domain: string;
  domain_name: string;
  name: string;
  description: string;
  icon: string;
  color: string;
  inputs: NodeInputPort[];
  outputs: NodeOutputPort[];
}

export async function listPipelines(): Promise<PipelineSummary[]> {
  const res = await fetch(`${API_BASE}/pipelines`);
  const data = await res.json();
  return data.pipelines || [];
}

export async function getPipeline(id: string): Promise<PipelineDefinition | null> {
  const res = await fetch(`${API_BASE}/pipelines/${id}`);
  const data = await res.json();
  return data.success ? data.pipeline : null;
}

export async function savePipeline(pipeline: Partial<PipelineDefinition>): Promise<PipelineDefinition> {
  const isNew = !pipeline.id || pipeline.id === '';
  const method = isNew ? 'POST' : 'PUT';
  const url = isNew ? `${API_BASE}/pipelines` : `${API_BASE}/pipelines/${pipeline.id}`;

  const res = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(pipeline),
  });
  const data = await res.json();
  return data.pipeline;
}

export async function deletePipeline(id: string): Promise<boolean> {
  const res = await fetch(`${API_BASE}/pipelines/${id}`, { method: 'DELETE' });
  const data = await res.json();
  return data.success;
}

export async function runPipeline(id: string, parameters?: Record<string, any>): Promise<any> {
  const res = await fetch(`${API_BASE}/pipelines/${id}/run`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ parameters: parameters || {} }),
  });
  return res.json();
}

export async function runPipelineFromNode(
  id: string,
  nodeId: string,
  parameters?: Record<string, any>,
  previousResults?: Record<string, any>,
): Promise<any> {
  const res = await fetch(`${API_BASE}/pipelines/${id}/run-from/${nodeId}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      parameters: parameters || {},
      previous_results: previousResults || {},
    }),
  });
  return res.json();
}

export async function getNodeCatalog(): Promise<NodeCatalogEntry[]> {
  const res = await fetch(`${API_BASE}/nodes/catalog`);
  const data = await res.json();
  return data.nodes || [];
}
