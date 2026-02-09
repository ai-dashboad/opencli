import { memo } from 'react';

interface NodeResultPreviewProps {
  status?: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  result?: Record<string, any>;
  error?: string;
}

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

  // Check for video/image URL output
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
