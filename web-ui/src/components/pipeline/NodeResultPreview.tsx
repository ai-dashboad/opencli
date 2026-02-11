import { memo } from 'react';

interface NodeResultPreviewProps {
  status?: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  result?: Record<string, any>;
  error?: string;
}

const DAEMON_FILES_BASE = 'http://localhost:9529/api/v1/files/';

/** Convert an absolute path under ~/.opencli/ to a daemon file-serve URL. */
function pathToFileUrl(path: string): string | null {
  // Already a URL
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  // Absolute path — extract relative portion after .opencli/
  const marker = '.opencli/';
  const idx = path.indexOf(marker);
  if (idx >= 0) {
    return DAEMON_FILES_BASE + path.substring(idx + marker.length);
  }
  return null;
}

/** Get the best servable URL from a result object. */
function resolveFileUrl(result: Record<string, any>): string | null {
  // Prefer explicit file_url from executor
  if (result.file_url && typeof result.file_url === 'string') return result.file_url;
  // Try common path fields
  for (const key of ['path', 'file_path', 'output_path']) {
    if (result[key] && typeof result[key] === 'string') {
      const url = pathToFileUrl(result[key]);
      if (url) return url;
    }
  }
  return null;
}

function getExtension(url: string): string {
  try {
    const pathname = new URL(url, 'http://localhost').pathname;
    const ext = pathname.split('.').pop()?.toLowerCase() || '';
    return ext;
  } catch {
    const ext = url.split('.').pop()?.toLowerCase() || '';
    return ext.split('?')[0];
  }
}

const IMAGE_EXTS = new Set(['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp']);
const VIDEO_EXTS = new Set(['mp4', 'webm', 'mov', 'avi', 'mkv']);
const AUDIO_EXTS = new Set(['wav', 'mp3', 'm4a', 'ogg', 'aac', 'flac']);

function NodeResultPreviewInner({ status, result, error }: NodeResultPreviewProps) {
  if (!status || status === 'pending') return null;

  if (status === 'running') {
    return (
      <div className="node-result-preview result-running">
        <span className="result-spinner" />
        <span>Running...</span>
      </div>
    );
  }

  if (status === 'failed') {
    return (
      <div className="node-result-preview result-failed">
        <span className="result-icon-fail">&#10005;</span>
        <span className="result-text">{error || result?.error || 'Failed'}</span>
      </div>
    );
  }

  if (status === 'skipped') {
    return (
      <div className="node-result-preview result-skipped">
        <span className="result-icon-skip">&#8594;</span>
        <span>Skipped</span>
      </div>
    );
  }

  // completed
  if (!result) return null;

  // Check for base64 image output (from AI image generation)
  if (result.image_base64 && typeof result.image_base64 === 'string') {
    return (
      <div className="node-result-preview result-completed">
        <img
          src={`data:image/png;base64,${result.image_base64}`}
          alt="generated"
          className="result-image"
        />
      </div>
    );
  }

  // Check for base64 video output (from AI video generation)
  if (result.video_base64 && typeof result.video_base64 === 'string') {
    const binary = atob(result.video_base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    const blob = new Blob([bytes], { type: 'video/mp4' });
    const blobUrl = URL.createObjectURL(blob);
    return (
      <div className="node-result-preview result-completed">
        <video src={blobUrl} className="result-video" controls muted />
      </div>
    );
  }

  // Check for file_url or path fields (from pipeline executor file serving)
  const fileUrl = resolveFileUrl(result);
  if (fileUrl) {
    const ext = getExtension(fileUrl);

    if (VIDEO_EXTS.has(ext)) {
      return (
        <div className="node-result-preview result-completed">
          <video src={fileUrl} className="result-video" controls muted />
        </div>
      );
    }

    if (IMAGE_EXTS.has(ext)) {
      return (
        <div className="node-result-preview result-completed">
          <img src={fileUrl} alt="result" className="result-image" />
        </div>
      );
    }

    if (AUDIO_EXTS.has(ext)) {
      return (
        <div className="node-result-preview result-completed">
          <audio src={fileUrl} controls style={{ width: '100%', maxWidth: 260 }} />
        </div>
      );
    }
  }

  // Check for video/image URL output (legacy fields)
  const mediaUrl = result.video_url || result.video_path || result.image_url;
  if (mediaUrl && typeof mediaUrl === 'string') {
    const isVideo = /\.(mp4|webm|mov)$/i.test(mediaUrl);
    if (isVideo) {
      return (
        <div className="node-result-preview result-completed">
          <video src={mediaUrl} className="result-video" controls muted />
        </div>
      );
    }
    if (/\.(png|jpg|jpeg|gif|webp)$/i.test(mediaUrl)) {
      return (
        <div className="node-result-preview result-completed">
          <img src={mediaUrl} alt="result" className="result-image" />
        </div>
      );
    }
  }

  // Text result
  const text = result.display || result.response || result.stdout || result.output || result.result;
  if (text) {
    const truncated = String(text).length > 200 ? String(text).substring(0, 200) + '...' : String(text);
    return (
      <div className="node-result-preview result-completed">
        <span className="result-icon-ok">&#10003;</span>
        <span className="result-text">{truncated}</span>
      </div>
    );
  }

  return (
    <div className="node-result-preview result-completed">
      <span className="result-icon-ok">&#10003;</span>
      <span className="result-text">Done</span>
    </div>
  );
}

export default memo(NodeResultPreviewInner);
