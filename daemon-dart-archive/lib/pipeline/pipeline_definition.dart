import 'dart:convert';

/// A visual pipeline definition containing nodes and edges.
///
/// Pipelines are DAGs (directed acyclic graphs) of task nodes.
/// Each node maps to an OpenCLI domain task type or control flow operation.
/// Edges define data flow between node ports.
class PipelineDefinition {
  final String id;
  String name;
  String description;
  final List<PipelineNode> nodes;
  final List<PipelineEdge> edges;
  final List<PipelineParam> parameters;
  final DateTime createdAt;
  DateTime updatedAt;

  PipelineDefinition({
    required this.id,
    required this.name,
    this.description = '',
    List<PipelineNode>? nodes,
    List<PipelineEdge>? edges,
    List<PipelineParam>? parameters,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : nodes = nodes ?? [],
        edges = edges ?? [],
        parameters = parameters ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory PipelineDefinition.fromJson(Map<String, dynamic> json) {
    return PipelineDefinition(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((n) => PipelineNode.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      edges: (json['edges'] as List<dynamic>?)
              ?.map((e) => PipelineEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      parameters: (json['parameters'] as List<dynamic>?)
              ?.map((p) => PipelineParam.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Get a summary for list views (without full node/edge data).
  Map<String, dynamic> toSummary() => {
        'id': id,
        'name': name,
        'description': description,
        'node_count': nodes.length,
        'edge_count': edges.length,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// A node in the pipeline graph.
class PipelineNode {
  final String id;
  final String type; // task type, e.g. 'weather_current', 'ai_query'
  final String domain; // domain id, e.g. 'weather', 'ai', 'control'
  String label;
  double x;
  double y;
  Map<String, dynamic> params;

  PipelineNode({
    required this.id,
    required this.type,
    required this.domain,
    this.label = '',
    this.x = 0,
    this.y = 0,
    Map<String, dynamic>? params,
  }) : params = params ?? {};

  factory PipelineNode.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    return PipelineNode(
      id: json['id'] as String,
      type: json['type'] as String,
      domain: json['domain'] as String? ?? '',
      label: json['label'] as String? ?? '',
      x: (pos?['x'] as num?)?.toDouble() ?? 0,
      y: (pos?['y'] as num?)?.toDouble() ?? 0,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'domain': domain,
        'label': label,
        'position': {'x': x, 'y': y},
        'params': params,
      };
}

/// An edge connecting two node ports.
class PipelineEdge {
  final String id;
  final String sourceNode;
  final String sourcePort;
  final String targetNode;
  final String targetPort;

  PipelineEdge({
    required this.id,
    required this.sourceNode,
    this.sourcePort = 'output',
    required this.targetNode,
    this.targetPort = 'input',
  });

  factory PipelineEdge.fromJson(Map<String, dynamic> json) {
    return PipelineEdge(
      id: json['id'] as String,
      sourceNode: json['source'] as String? ?? json['source_node'] as String,
      sourcePort: json['source_port'] as String? ?? 'output',
      targetNode: json['target'] as String? ?? json['target_node'] as String,
      targetPort: json['target_port'] as String? ?? 'input',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': sourceNode,
        'source_port': sourcePort,
        'target': targetNode,
        'target_port': targetPort,
      };
}

/// A pipeline-level parameter that can be overridden at execution time.
class PipelineParam {
  final String name;
  final String type; // 'string', 'number', 'boolean'
  final dynamic defaultValue;
  final String description;

  PipelineParam({
    required this.name,
    this.type = 'string',
    this.defaultValue,
    this.description = '',
  });

  factory PipelineParam.fromJson(Map<String, dynamic> json) {
    return PipelineParam(
      name: json['name'] as String,
      type: json['type'] as String? ?? 'string',
      defaultValue: json['default'],
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'default': defaultValue,
        'description': description,
      };
}
