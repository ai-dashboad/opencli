import { OpenCliClient } from '../api/client';
import './QuickActions.css';

interface QuickActionsProps {
  client: OpenCliClient;
}

export default function QuickActions({ client }: QuickActionsProps) {
  const handleAction = async (method: string, params: string[] = []) => {
    try {
      await client.execute(method, params);
      alert('Action completed successfully');
    } catch (error) {
      alert(`Action failed: ${error}`);
    }
  };

  return (
    <div className="quick-actions">
      <h3>Quick Actions</h3>

      <div className="action-group">
        <h4>Flutter</h4>
        <button onClick={() => handleAction('flutter.launch', ['--device=macos'])}>
          🚀 Launch App
        </button>
        <button onClick={() => handleAction('flutter.hot_reload')}>
          🔥 Hot Reload
        </button>
        <button onClick={() => handleAction('flutter.screenshot')}>
          📸 Screenshot
        </button>
      </div>

      <div className="action-group">
        <h4>System</h4>
        <button onClick={() => handleAction('system.health')}>
          ❤️ Health Check
        </button>
        <button onClick={() => handleAction('system.plugins')}>
          🔌 List Plugins
        </button>
      </div>
    </div>
  );
}
