import { useState, useEffect, useRef, useCallback } from 'react';

interface UseDaemonOptions {
  deviceId?: string;
  autoConnect?: boolean;
}

interface UseDaemonReturn {
  connected: boolean;
  authenticated: boolean;
  send: (msg: object) => void;
  submitTask: (taskType: string, taskData: Record<string, any>) => void;
  subscribe: (handler: (msg: any) => void) => () => void;
}

async function generateAuthToken(deviceId: string, timestamp: number): Promise<string> {
  const input = `${deviceId}:${timestamp}:opencli-dev-secret`;
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export function useDaemon(options?: UseDaemonOptions): UseDaemonReturn {
  const deviceId = options?.deviceId ?? 'web_dashboard';
  const [connected, setConnected] = useState(false);
  const [authenticated, setAuthenticated] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);
  const subscribersRef = useRef<Set<(msg: any) => void>>(new Set());
  const reconnectRef = useRef<ReturnType<typeof setTimeout>>();
  const mountedRef = useRef(true);

  const send = useCallback((msg: object) => {
    const ws = wsRef.current;
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(msg));
    }
  }, []);

  const submitTask = useCallback((taskType: string, taskData: Record<string, any>) => {
    send({ type: 'submit_task', task_type: taskType, task_data: taskData });
  }, [send]);

  const subscribe = useCallback((handler: (msg: any) => void) => {
    subscribersRef.current.add(handler);
    return () => { subscribersRef.current.delete(handler); };
  }, []);

  useEffect(() => {
    mountedRef.current = true;

    const connect = () => {
      if (!mountedRef.current) return;
      try {
        const ws = new WebSocket('ws://localhost:9876');
        wsRef.current = ws;

        ws.onopen = async () => {
          if (!mountedRef.current) return;
          setConnected(true);
          const timestamp = Date.now();
          const token = await generateAuthToken(deviceId, timestamp);
          ws.send(JSON.stringify({
            type: 'auth',
            device_id: deviceId,
            token,
            timestamp,
          }));
        };

        ws.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            if (data.type === 'auth_success') {
              setAuthenticated(true);
            }
            subscribersRef.current.forEach(handler => handler(data));
          } catch (e) {
            console.error('WS parse error:', e);
          }
        };

        ws.onclose = () => {
          if (!mountedRef.current) return;
          setConnected(false);
          setAuthenticated(false);
          reconnectRef.current = setTimeout(connect, 5000);
        };

        ws.onerror = () => {
          setConnected(false);
        };
      } catch {
        setConnected(false);
        reconnectRef.current = setTimeout(connect, 5000);
      }
    };

    connect();

    return () => {
      mountedRef.current = false;
      clearTimeout(reconnectRef.current);
      wsRef.current?.close();
    };
  }, [deviceId]);

  return { connected, authenticated, send, submitTask, subscribe };
}
