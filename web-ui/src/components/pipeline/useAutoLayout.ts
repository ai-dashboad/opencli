/**
 * Auto-layout and alignment utilities for pipeline editors.
 * Uses dagre for DAG-based automatic node arrangement.
 */
import { useCallback } from 'react';
import { useReactFlow, type Node, type Edge } from '@xyflow/react';
import Dagre from '@dagrejs/dagre';

const NODE_WIDTH = 260;
const NODE_HEIGHT = 180;

/** Auto-layout all nodes using dagre (left-to-right DAG) */
export function getLayoutedElements(nodes: Node[], edges: Edge[], direction: 'LR' | 'TB' = 'LR') {
  const g = new Dagre.graphlib.Graph().setDefaultEdgeLabel(() => ({}));
  g.setGraph({
    rankdir: direction,
    nodesep: 60,
    ranksep: 120,
    marginx: 40,
    marginy: 40,
  });

  nodes.forEach((node) => {
    g.setNode(node.id, { width: NODE_WIDTH, height: NODE_HEIGHT });
  });

  edges.forEach((edge) => {
    g.setEdge(edge.source, edge.target);
  });

  Dagre.layout(g);

  const layoutedNodes = nodes.map((node) => {
    const pos = g.node(node.id);
    return {
      ...node,
      position: {
        x: pos.x - NODE_WIDTH / 2,
        y: pos.y - NODE_HEIGHT / 2,
      },
    };
  });

  return layoutedNodes;
}

/** Hook providing layout and alignment actions */
export function useLayoutActions() {
  const { getNodes, setNodes, getEdges, fitView } = useReactFlow();

  /** Auto-layout all nodes with dagre */
  const autoLayout = useCallback((direction: 'LR' | 'TB' = 'LR') => {
    const nodes = getNodes();
    const edges = getEdges();
    if (nodes.length === 0) return;
    const layouted = getLayoutedElements(nodes, edges, direction);
    setNodes(layouted);
    setTimeout(() => fitView({ padding: 0.15, duration: 300 }), 50);
  }, [getNodes, getEdges, setNodes, fitView]);

  /** Fit all nodes into view */
  const fitAll = useCallback(() => {
    fitView({ padding: 0.15, duration: 300 });
  }, [fitView]);

  /** Align selected nodes (or all if none selected) */
  const alignNodes = useCallback((alignment: 'left' | 'right' | 'top' | 'bottom' | 'center-h' | 'center-v') => {
    const allNodes = getNodes();
    const selected = allNodes.filter(n => n.selected);
    const targets = selected.length >= 2 ? selected : allNodes;
    if (targets.length < 2) return;

    const ids = new Set(targets.map(n => n.id));

    let ref: number;
    switch (alignment) {
      case 'left':
        ref = Math.min(...targets.map(n => n.position.x));
        setNodes(nds => nds.map(n => ids.has(n.id) ? { ...n, position: { ...n.position, x: ref } } : n));
        break;
      case 'right':
        ref = Math.max(...targets.map(n => n.position.x));
        setNodes(nds => nds.map(n => ids.has(n.id) ? { ...n, position: { ...n.position, x: ref } } : n));
        break;
      case 'top':
        ref = Math.min(...targets.map(n => n.position.y));
        setNodes(nds => nds.map(n => ids.has(n.id) ? { ...n, position: { ...n.position, y: ref } } : n));
        break;
      case 'bottom':
        ref = Math.max(...targets.map(n => n.position.y));
        setNodes(nds => nds.map(n => ids.has(n.id) ? { ...n, position: { ...n.position, y: ref } } : n));
        break;
      case 'center-h': {
        const minY = Math.min(...targets.map(n => n.position.y));
        const maxY = Math.max(...targets.map(n => n.position.y));
        ref = (minY + maxY) / 2;
        setNodes(nds => nds.map(n => ids.has(n.id) ? { ...n, position: { ...n.position, y: ref } } : n));
        break;
      }
      case 'center-v': {
        const minX = Math.min(...targets.map(n => n.position.x));
        const maxX = Math.max(...targets.map(n => n.position.x));
        ref = (minX + maxX) / 2;
        setNodes(nds => nds.map(n => ids.has(n.id) ? { ...n, position: { ...n.position, x: ref } } : n));
        break;
      }
    }
  }, [getNodes, setNodes]);

  /** Distribute selected nodes evenly */
  const distributeNodes = useCallback((axis: 'horizontal' | 'vertical') => {
    const allNodes = getNodes();
    const selected = allNodes.filter(n => n.selected);
    const targets = selected.length >= 3 ? selected : allNodes;
    if (targets.length < 3) return;

    const ids = new Set(targets.map(n => n.id));
    const sorted = [...targets].sort((a, b) =>
      axis === 'horizontal' ? a.position.x - b.position.x : a.position.y - b.position.y
    );

    const first = sorted[0].position;
    const last = sorted[sorted.length - 1].position;
    const total = axis === 'horizontal' ? last.x - first.x : last.y - first.y;
    const step = total / (sorted.length - 1);

    const posMap = new Map<string, number>();
    sorted.forEach((n, i) => {
      posMap.set(n.id, (axis === 'horizontal' ? first.x : first.y) + step * i);
    });

    setNodes(nds => nds.map(n => {
      if (!ids.has(n.id)) return n;
      const val = posMap.get(n.id)!;
      return {
        ...n,
        position: axis === 'horizontal'
          ? { ...n.position, x: val }
          : { ...n.position, y: val },
      };
    }));
  }, [getNodes, setNodes]);

  return { autoLayout, fitAll, alignNodes, distributeNodes };
}
