import 'dart:convert';
import 'package:opencli_daemon/database/app_database.dart';
import 'pipeline_definition.dart';

/// SQLite-backed storage for pipeline definitions.
///
/// Stores pipelines in the centralized AppDatabase.
class PipelineStore {
  final AppDatabase _db;

  PipelineStore({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  /// Initialize (no-op now — DB is initialized at daemon startup).
  Future<void> initialize() async {}

  /// List all saved pipelines (summary only).
  Future<List<Map<String, dynamic>>> list() async {
    final rows = await _db.listPipelines();
    return rows.map((row) {
      // Decode nodes/edges to get counts (if full row is available)
      final nodeCount = _countJson(row['nodes']);
      final edgeCount = _countJson(row['edges']);
      return {
        'id': row['id'],
        'name': row['name'],
        'description': row['description'] ?? '',
        'node_count': nodeCount,
        'edge_count': edgeCount,
        'created_at': DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int).toIso8601String(),
        'updated_at': DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int).toIso8601String(),
      };
    }).toList();
  }

  int _countJson(dynamic value) {
    if (value == null) return 0;
    try {
      final list = jsonDecode(value as String);
      return (list as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Load a pipeline by ID.
  Future<PipelineDefinition?> load(String id) async {
    final row = await _db.getPipeline(id);
    if (row == null) return null;
    return _rowToPipeline(row);
  }

  /// Save a pipeline (creates or overwrites).
  Future<void> save(PipelineDefinition pipeline) async {
    pipeline.updatedAt = DateTime.now();
    await _db.upsertPipeline({
      'id': pipeline.id,
      'name': pipeline.name,
      'description': pipeline.description,
      'nodes': jsonEncode(pipeline.nodes.map((n) => n.toJson()).toList()),
      'edges': jsonEncode(pipeline.edges.map((e) => e.toJson()).toList()),
      'parameters':
          jsonEncode(pipeline.parameters.map((p) => p.toJson()).toList()),
      'created_at': pipeline.createdAt.millisecondsSinceEpoch,
      'updated_at': pipeline.updatedAt.millisecondsSinceEpoch,
    });
  }

  /// Delete a pipeline by ID. Returns true if deleted.
  Future<bool> delete(String id) async {
    return await _db.deletePipeline(id);
  }

  /// Check if a pipeline exists.
  Future<bool> exists(String id) async {
    return await _db.pipelineExists(id);
  }

  /// Convert a database row to PipelineDefinition.
  PipelineDefinition _rowToPipeline(Map<String, dynamic> row) {
    final nodesJson = jsonDecode(row['nodes'] as String) as List<dynamic>;
    final edgesJson = jsonDecode(row['edges'] as String) as List<dynamic>;
    final paramsJson = jsonDecode(row['parameters'] as String? ?? '[]') as List<dynamic>;

    return PipelineDefinition(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Untitled',
      description: row['description'] as String? ?? '',
      nodes: nodesJson
          .map((n) => PipelineNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      edges: edgesJson
          .map((e) => PipelineEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
      parameters: paramsJson
          .map((p) => PipelineParam.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
