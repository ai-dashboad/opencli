import { createContext, useContext } from 'react';

export interface PipelineContextValue {
  onPlayFromHere: (nodeId: string) => void;
  isRunning: boolean;
  nodeResults: Record<string, Record<string, any>>;
}

const PipelineContext = createContext<PipelineContextValue>({
  onPlayFromHere: () => {},
  isRunning: false,
  nodeResults: {},
});

export const PipelineProvider = PipelineContext.Provider;

export function usePipelineContext() {
  return useContext(PipelineContext);
}
