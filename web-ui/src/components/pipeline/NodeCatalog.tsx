import { useState, useEffect } from 'react';
import type { NodeCatalogEntry } from '../../api/pipeline-api';
import { getNodeCatalog } from '../../api/pipeline-api';
import { daemonColorToCss, getDomainIcon } from './dataTypeColors';

interface NodeCatalogProps {
  onDragStart: (event: React.DragEvent, node: NodeCatalogEntry) => void;
}

export default function NodeCatalog({ onDragStart }: NodeCatalogProps) {
  const [nodes, setNodes] = useState<NodeCatalogEntry[]>([]);
  const [search, setSearch] = useState('');
  const [expandedDomains, setExpandedDomains] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadCatalog();
  }, []);

  const loadCatalog = async () => {
    try {
      const catalog = await getNodeCatalog();
      setNodes(catalog);
      // Expand all domains by default
      const domains = new Set(catalog.map(n => n.domain));
      setExpandedDomains(domains);
    } catch (e) {
      console.error('Failed to load node catalog:', e);
    } finally {
      setLoading(false);
    }
  };

  const filteredNodes = search
    ? nodes.filter(n =>
        n.name.toLowerCase().includes(search.toLowerCase()) ||
        n.type.toLowerCase().includes(search.toLowerCase()) ||
        n.domain_name.toLowerCase().includes(search.toLowerCase())
      )
    : nodes;

  // Group by domain
  const grouped = filteredNodes.reduce((acc, node) => {
    if (!acc[node.domain]) acc[node.domain] = { name: node.domain_name, color: node.color, nodes: [] };
    acc[node.domain].nodes.push(node);
    return acc;
  }, {} as Record<string, { name: string; color: string; nodes: NodeCatalogEntry[] }>);

  const toggleDomain = (domain: string) => {
    setExpandedDomains(prev => {
      const next = new Set(prev);
      if (next.has(domain)) next.delete(domain);
      else next.add(domain);
      return next;
    });
  };

  if (loading) {
    return <div className="node-catalog"><div className="catalog-loading">Loading nodes...</div></div>;
  }

  return (
    <div className="node-catalog">
      <div className="catalog-header">
        <div className="catalog-title">NODE CATALOG</div>
        <input
          type="text"
          className="catalog-search"
          placeholder="Search nodes..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="catalog-list">
        {Object.entries(grouped).map(([domain, group]) => {
          const domainColor = daemonColorToCss(group.color);
          const iconName = getDomainIcon(domain);

          return (
            <div key={domain} className="catalog-domain">
              <div
                className="domain-header"
                onClick={() => toggleDomain(domain)}
              >
                <span className="domain-arrow">
                  {expandedDomains.has(domain) ? '\u25BE' : '\u25B8'}
                </span>
                <span
                  className="material-icons catalog-domain-icon"
                  style={{ fontSize: 16, color: domainColor }}
                >
                  {iconName}
                </span>
                <span className="domain-name">{group.name}</span>
                <span className="domain-count">{group.nodes.length}</span>
              </div>

              {expandedDomains.has(domain) && (
                <div className="domain-nodes">
                  {group.nodes.map((node) => (
                    <div
                      key={node.type}
                      className="catalog-node"
                      draggable
                      onDragStart={(e) => onDragStart(e, node)}
                      title={node.description}
                    >
                      <div className="catalog-node-row">
                        <span
                          className="material-icons catalog-node-icon"
                          style={{ fontSize: 14, color: domainColor }}
                        >
                          {iconName}
                        </span>
                        <span className="node-name">{node.name}</span>
                      </div>
                      <span className="node-type">{node.type}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}

        {Object.keys(grouped).length === 0 && (
          <div className="catalog-empty">No nodes found</div>
        )}
      </div>
    </div>
  );
}
