import { memo, useCallback, useRef, useEffect } from 'react';
import type { NodeInputPort } from '../../api/pipeline-api';

interface InlineParamInputProps {
  port: NodeInputPort;
  value: any;
  onChange: (name: string, value: any) => void;
}

function InlineParamInputInner({ port, value, onChange }: InlineParamInputProps) {
  const timerRef = useRef<ReturnType<typeof setTimeout>>();
  const currentValue = value ?? port.defaultValue ?? '';

  const handleChange = useCallback(
    (newValue: any) => {
      if (timerRef.current) clearTimeout(timerRef.current);
      timerRef.current = setTimeout(() => {
        onChange(port.name, newValue);
      }, 150);
    },
    [onChange, port.name]
  );

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, []);

  const inputType = port.inputType || 'text';

  switch (inputType) {
    case 'textarea':
      return (
        <textarea
          className="node-inline-textarea nodrag nopan"
          defaultValue={currentValue}
          placeholder={port.description || port.name}
          onChange={(e) => handleChange(e.target.value)}
          rows={3}
        />
      );

    case 'select':
      return (
        <select
          className="node-inline-select nodrag nopan"
          defaultValue={currentValue}
          onChange={(e) => handleChange(e.target.value)}
        >
          {!currentValue && <option value="">Select...</option>}
          {(port.options || []).map((opt) => (
            <option key={opt} value={opt}>
              {opt}
            </option>
          ))}
        </select>
      );

    case 'slider': {
      const min = port.min ?? 0;
      const max = port.max ?? 100;
      const step = port.step ?? 1;
      const numVal = parseFloat(currentValue) || min;
      return (
        <div className="node-inline-slider-wrap nodrag nopan">
          <input
            type="range"
            className="node-inline-slider"
            min={min}
            max={max}
            step={step}
            defaultValue={numVal}
            onChange={(e) => handleChange(parseFloat(e.target.value))}
          />
          <span className="slider-value">{numVal}</span>
        </div>
      );
    }

    case 'toggle':
      return (
        <label className="node-inline-toggle nodrag nopan">
          <input
            type="checkbox"
            defaultChecked={!!currentValue}
            onChange={(e) => handleChange(e.target.checked)}
          />
          <span className="toggle-slider" />
        </label>
      );

    default:
      return (
        <input
          type="text"
          className="node-inline-input nodrag nopan"
          defaultValue={currentValue}
          placeholder={port.description || `{{nodeId.field}}`}
          onChange={(e) => handleChange(e.target.value)}
        />
      );
  }
}

export default memo(InlineParamInputInner);
