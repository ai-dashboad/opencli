import { useState, useEffect, useCallback } from 'react';

type ToastType = 'success' | 'error' | 'info';

interface ToastMessage {
  id: number;
  text: string;
  type: ToastType;
}

let _addToast: ((text: string, type?: ToastType) => void) | null = null;

/** Call from anywhere to show a toast notification. */
export function showToast(text: string, type: ToastType = 'info') {
  _addToast?.(text, type);
}

let _nextId = 1;

export default function ToastContainer() {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  const addToast = useCallback((text: string, type: ToastType = 'info') => {
    const id = _nextId++;
    setToasts(prev => [...prev, { id, text, type }]);
    setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 3000);
  }, []);

  useEffect(() => { _addToast = addToast; return () => { _addToast = null; }; }, [addToast]);

  if (toasts.length === 0) return null;

  const icons: Record<ToastType, string> = { success: 'check_circle', error: 'error', info: 'info' };

  return (
    <div className="toast-container">
      {toasts.map(t => (
        <div key={t.id} className={`toast-item toast-${t.type}`}>
          <span className="material-icons toast-icon">{icons[t.type]}</span>
          <span className="toast-text">{t.text}</span>
          <button className="toast-close" onClick={() => setToasts(prev => prev.filter(x => x.id !== t.id))}>
            <span className="material-icons">close</span>
          </button>
        </div>
      ))}
    </div>
  );
}
