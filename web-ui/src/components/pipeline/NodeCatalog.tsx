import { useState, useEffect } from 'react';
import type { NodeCatalogEntry } from '../../api/pipeline-api';
import { getVideoNodeCatalog } from '../../api/pipeline-api';
import { getNodeIcon } from './dataTypeColors';

interface NodeCatalogProps {
  onDragStart: (event: React.DragEvent, node: NodeCatalogEntry) => void;
}

const CATEGORY_ORDER = ['input', 'process', 'output'];

export default function NodeCatalog({ onDragStart }: NodeCatalogProps) {
  const [nodes, setNodes] = useState<NodeCatalogEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadCatalog();
  }, []);

  const loadCatalog = async () => {
    try {
      const catalog = await getVideoNodeCatalog();
      setNodes(catalog);
    } catch (e) {
      console.error('Failed to load video node catalog:', e);
    } finally {
      setLoading(false);
    }
  };

  // Group by category
  const grouped = nodes.reduce((acc, node) => {
    const cat = node.category || 'process';
    if (!acc[cat]) acc[cat] = [];
    acc[cat].push(node);
    return acc;
  }, {} as Record<string, NodeCatalogEntry[]>);

  // Sort categories in order
  const sortedCategories = CATEGORY_ORDER.filter((cat) => grouped[cat]);

  if (loading) {
    return (
      <div className="node-catalog">
        <div className="catalog-header">
          <div className="catalog-title">Nodes</div>
        </div>
        <div className="catalog-loading">Loading...</div>
      </div>
    );
  }

  return (
    <div className="node-catalog">
      <div className="catalog-header">
        <div className="catalog-title">Nodes</div>
      </div>

      <div className="catalog-list">
        {sortedCategories.map((category) => (
          <div key={category} className="catalog-category-group">
            <div className="catalog-category">{category}</div>
            {grouped[category].map((node) => (
              <div
                key={node.type}
                className="catalog-node"
                draggable
                onDragStart={(e) => onDragStart(e, node)}
                title={node.description}
              >
                <span className="catalog-node-icon">{getNodeIcon(node.type)}</span>
                <span className="catalog-node-name">{node.name}</span>
              </div>
            ))}
          </div>
        ))}

        {sortedCategories.length === 0 && (
          <div className="catalog-empty">No nodes available</div>
        )}
      </div>
    </div>
  );
}
