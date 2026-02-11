const API_BASE = 'http://localhost:9529/api/v1';

export interface EpisodeSummary {
  id: string;
  title: string;
  synopsis: string;
  status: string;
  progress: number;
  output_path?: string;
  pipeline_id?: string | null;
  created_at: number;
  updated_at: number;
}

export interface DialogueLine {
  character_id: string;
  text: string;
  emotion: string;
  voice_id: string;
}

export interface EpisodeScene {
  id: string;
  title: string;
  visual_description: string;
  setting_description: string;
  dialogue: DialogueLine[];
  character_ids: string[];
  bgm_track: string | null;
  bgm_volume: number;
  transition: string;
  video_duration_seconds: number;
}

export interface CharacterDefinition {
  id: string;
  name: string;
  visual_description: string;
  default_voice: string;
}

export interface EpisodeScript {
  id: string;
  title: string;
  synopsis: string;
  language: string;
  style: string;
  scenes: EpisodeScene[];
  characters: CharacterDefinition[];
}

export async function listEpisodes(): Promise<EpisodeSummary[]> {
  const res = await fetch(`${API_BASE}/episodes`);
  const data = await res.json();
  return data.episodes || [];
}

export async function getEpisode(id: string): Promise<{ episode: any } | null> {
  const res = await fetch(`${API_BASE}/episodes/${id}`);
  const data = await res.json();
  return data.success ? data : null;
}

export async function createEpisodeFromText(
  text: string,
  options?: { language?: string; style?: string; maxScenes?: number }
): Promise<any> {
  const res = await fetch(`${API_BASE}/episodes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text,
      language: options?.language ?? 'zh-CN',
      style: options?.style ?? 'anime',
      max_scenes: options?.maxScenes ?? 8,
    }),
  });
  return res.json();
}

export async function createEpisodeFromScript(script: EpisodeScript): Promise<any> {
  const res = await fetch(`${API_BASE}/episodes/from-script`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ script }),
  });
  return res.json();
}

export async function updateEpisode(id: string, script: EpisodeScript): Promise<any> {
  const res = await fetch(`${API_BASE}/episodes/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ script }),
  });
  return res.json();
}

export async function deleteEpisode(id: string): Promise<boolean> {
  const res = await fetch(`${API_BASE}/episodes/${id}`, { method: 'DELETE' });
  const data = await res.json();
  return data.success;
}

export async function generateEpisode(
  id: string,
  options?: {
    image_provider?: string;
    video_provider?: string;
    quality?: string;
    color_grade_lut?: string;
    export_platform?: string;
    use_pipeline?: boolean;
  }
): Promise<any> {
  const res = await fetch(`${API_BASE}/episodes/${id}/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(options || {}),
  });
  return res.json();
}

export async function getEpisodeProgress(id: string): Promise<{
  status: string;
  progress: number;
  output_path?: string;
}> {
  const res = await fetch(`${API_BASE}/episodes/${id}/progress`);
  return res.json();
}

export async function cancelEpisode(id: string): Promise<any> {
  const res = await fetch(`${API_BASE}/episodes/${id}/cancel`, { method: 'POST' });
  return res.json();
}

// ── Pipeline integration ─────────────────────────────────────────

export interface PipelineTemplate {
  id: string;
  name: string;
  description: string;
  node_count: number;
}

export async function buildEpisodePipeline(
  id: string,
  settings?: Record<string, any>
): Promise<{ success: boolean; pipeline_id?: string; pipeline?: any }> {
  const res = await fetch(`${API_BASE}/episodes/${id}/build-pipeline`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(settings || {}),
  });
  return res.json();
}

export async function getEpisodePipeline(
  id: string
): Promise<{ success: boolean; pipeline_id?: string; pipeline?: any }> {
  const res = await fetch(`${API_BASE}/episodes/${id}/pipeline`);
  return res.json();
}

export async function listPipelineTemplates(): Promise<PipelineTemplate[]> {
  const res = await fetch(`${API_BASE}/pipeline-templates`);
  const data = await res.json();
  return data.templates || [];
}

export async function applyPipelineTemplate(
  episodeId: string,
  templateId: string
): Promise<{ success: boolean; pipeline_id?: string; pipeline?: any }> {
  const res = await fetch(`${API_BASE}/episodes/${episodeId}/apply-template`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ template_id: templateId }),
  });
  return res.json();
}
