import 'dart:convert';
import 'dart:io';
import 'pipeline_definition.dart';

/// File-system backed storage for pipeline definitions.
///
/// Stores each pipeline as a JSON file under ~/.opencli/pipelines/.
class PipelineStore {
  final String _baseDir;

  PipelineStore({String? baseDir})
      : _baseDir = baseDir ??
            '${Platform.environment['HOME']}/.opencli/pipelines';

  /// Ensure the storage directory exists.
  Future<void> initialize() async {
    final dir = Directory(_baseDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// List all saved pipelines (summary only).
  Future<List<Map<String, dynamic>>> list() async {
    await initialize();
    final dir = Directory(_baseDir);
    final summaries = <Map<String, dynamic>>[];

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final pipeline = PipelineDefinition.fromJson(json);
          summaries.add(pipeline.toSummary());
        } catch (e) {
          // Skip malformed files
          print('[PipelineStore] Warning: could not read ${entity.path}: $e');
        }
      }
    }

    summaries.sort((a, b) =>
        (b['updated_at'] as String).compareTo(a['updated_at'] as String));
    return summaries;
  }

  /// Load a pipeline by ID.
  Future<PipelineDefinition?> load(String id) async {
    final file = File('$_baseDir/$id.json');
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return PipelineDefinition.fromJson(json);
  }

  /// Save a pipeline (creates or overwrites).
  Future<void> save(PipelineDefinition pipeline) async {
    await initialize();
    pipeline.updatedAt = DateTime.now();
    final file = File('$_baseDir/${pipeline.id}.json');
    await file.writeAsString(pipeline.toJsonString());
  }

  /// Delete a pipeline by ID. Returns true if deleted.
  Future<bool> delete(String id) async {
    final file = File('$_baseDir/$id.json');
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Check if a pipeline exists.
  Future<bool> exists(String id) async {
    return File('$_baseDir/$id.json').exists();
  }
}
