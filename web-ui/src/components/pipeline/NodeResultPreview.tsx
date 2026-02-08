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
        <span className="material-icons" style={{ fontSize: 14 }}>error</span>
        <span className="result-text">{error || result?.error || 'Failed'}</span>
      </div>
    );
  }

  if (status === 'skipped') {
    return (
      <div className="node-result-preview result-skipped">
        <span className="material-icons" style={{ fontSize: 14 }}>skip_next</span>
        <span>Skipped</span>
      </div>
    );
  }

  // completed
  if (!result) return null;

  // Check for image output
  const imageUrl = result.image_url || result.video_path;
  if (imageUrl && typeof imageUrl === 'string' && /\.(png|jpg|jpeg|gif|webp|mp4)$/i.test(imageUrl)) {
    return (
      <div className="node-result-preview result-completed">
        <img src={imageUrl} alt="result" className="result-image" />
      </div>
    );
  }

  // Text result — prefer display, then response, then output
  const text = result.display || result.response || result.stdout || result.output || result.result;
  if (text) {
    const truncated = String(text).length > 200 ? String(text).substring(0, 200) + '...' : String(text);
    return (
      <div className="node-result-preview result-completed">
        <span className="result-text">{truncated}</span>
      </div>
    );
  }

  return (
    <div className="node-result-preview result-completed">
      <span className="result-text" style={{ color: '#4CAF50' }}>Done</span>
    </div>
  );
}

export default memo(NodeResultPreviewInner);
