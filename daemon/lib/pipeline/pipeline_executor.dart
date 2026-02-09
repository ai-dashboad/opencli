import 'dart:async';
import 'pipeline_definition.dart';
import 'pipeline_store.dart';
import '../mobile/mobile_task_handler.dart';
import '../domains/domain_plugin_adapter.dart';

/// Callback for pipeline execution progress updates.
typedef PipelineProgressCallback = void Function(Map<String, dynamic> update);

/// Status of a node during pipeline execution.
enum NodeStatus { pending, running, completed, failed, skipped }

/// Executes a pipeline graph by topologically sorting nodes and running them
/// in dependency order, with parallelism for independent nodes.
///
/// Registered as a [TaskExecutor] for the `pipeline_execute` task type.
class PipelineExecutor extends TaskExecutor {
  final PipelineStore store;
  final Map<String, TaskExecutor> _executors;
  PipelineProgressCallback? onProgress;

  PipelineExecutor({
    required this.store,
    required Map<String, TaskExecutor> executors,
    this.onProgress,
  }) : _executors = executors;

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final pipelineId = taskData['pipeline_id'] as String?;
    final overrideParams =
        taskData['parameters'] as Map<String, dynamic>? ?? {};

    if (pipelineId == null) {
      // Inline pipeline definition (sent directly from editor)
      if (taskData.containsKey('pipeline')) {
        final pipeline = PipelineDefinition.fromJson(
            taskData['pipeline'] as Map<String, dynamic>);
        return _executePipeline(pipeline, overrideParams);
      }
      return {'success': false, 'error': 'Missing pipeline_id or pipeline'};
    }

    final pipeline = await store.load(pipelineId);
    if (pipeline == null) {
      return {'success': false, 'error': 'Pipeline not found: $pipelineId'};
    }

    return _executePipeline(pipeline, overrideParams);
  }

  Future<Map<String, dynamic>> _executePipeline(
    PipelineDefinition pipeline,
    Map<String, dynamic> overrideParams,
  ) async {
    final stopwatch = Stopwatch()..start();
    final nodeResults = <String, Map<String, dynamic>>{};
    final nodeStatuses = <String, NodeStatus>{};

    // Initialize all node statuses
    for (final node in pipeline.nodes) {
      nodeStatuses[node.id] = NodeStatus.pending;
    }

    // Build adjacency info for topological sort
    final inDegree = <String, int>{};
    final dependents = <String, List<String>>{}; // source → [targets]
    final dependencies = <String, Set<String>>{}; // target → {sources}

    for (final node in pipeline.nodes) {
      inDegree[node.id] = 0;
      dependents[node.id] = [];
      dependencies[node.id] = {};
    }

    for (final edge in pipeline.edges) {
      inDegree[edge.targetNode] = (inDegree[edge.targetNode] ?? 0) + 1;
      dependents[edge.sourceNode]?.add(edge.targetNode);
      dependencies[edge.targetNode]?.add(edge.sourceNode);
    }

    // Detect cycles
    final visited = <String>{};
    final tempVisited = <String>{};
    for (final node in pipeline.nodes) {
      if (_hasCycle(node.id, dependents, visited, tempVisited)) {
        return {
          'success': false,
          'error': 'Pipeline contains a cycle',
        };
      }
    }

    // BFS-based level execution (Kahn's algorithm)
    final queue = <String>[];
    for (final node in pipeline.nodes) {
      if (inDegree[node.id] == 0) {
        queue.add(node.id);
      }
    }

    int completedCount = 0;
    final totalNodes = pipeline.nodes.length;
    bool hasFailed = false;

    while (queue.isNotEmpty) {
      // Execute all nodes in current level in parallel
      final currentLevel = List<String>.from(queue);
      queue.clear();

      final futures = <Future<void>>[];
      for (final nodeId in currentLevel) {
        futures.add(_executeNode(
          nodeId,
          pipeline,
          nodeResults,
          nodeStatuses,
          overrideParams,
        ));
      }

      await Future.wait(futures);

      // Check results and queue next level
      for (final nodeId in currentLevel) {
        completedCount++;
        final status = nodeStatuses[nodeId]!;

        _emitProgress(pipeline.id, nodeId, pipeline, nodeStatuses, nodeResults,
            completedCount / totalNodes);

        if (status == NodeStatus.failed) {
          hasFailed = true;
          // Mark all dependents as skipped
          _skipDownstream(nodeId, dependents, nodeStatuses);
          continue;
        }

        // Reduce in-degree of dependents
        for (final dep in dependents[nodeId]!) {
          inDegree[dep] = (inDegree[dep] ?? 1) - 1;
          if (inDegree[dep] == 0 &&
              nodeStatuses[dep] != NodeStatus.skipped) {
            queue.add(dep);
          }
        }
      }
    }

    stopwatch.stop();

    return {
      'success': !hasFailed,
      'pipeline_id': pipeline.id,
      'pipeline_name': pipeline.name,
      'node_results': nodeResults,
      'duration_ms': stopwatch.elapsedMilliseconds,
      'nodes_executed': completedCount,
      'nodes_total': totalNodes,
    };
  }

  /// Execute a single node.
  Future<void> _executeNode(
    String nodeId,
    PipelineDefinition pipeline,
    Map<String, Map<String, dynamic>> nodeResults,
    Map<String, NodeStatus> nodeStatuses,
    Map<String, dynamic> overrideParams,
  ) async {
    final node = pipeline.nodes.firstWhere((n) => n.id == nodeId);
    nodeStatuses[nodeId] = NodeStatus.running;

    try {
      // Resolve parameters: substitute {{nodeId.field}} references
      final resolvedParams =
          _resolveNodeParams(node.params, nodeResults, overrideParams);

      // Find executor for this task type
      final executor = _executors[node.type];
      if (executor == null) {
        throw Exception('No executor for task type: ${node.type}');
      }

      // Use executeWithProgress for domain tasks (supports progress callbacks)
      Map<String, dynamic> result;
      if (executor is DomainTaskExecutor) {
        result = await executor.executeWithProgress(resolvedParams,
            onProgress: (update) {
          // Emit per-node progress
          onProgress?.call({
            'pipeline_id': pipeline.id,
            'current_node': nodeId,
            'node_progress': update,
          });
        }).timeout(
              const Duration(minutes: 5),
              onTimeout: () =>
                  {'success': false, 'error': 'Node execution timed out'},
            );
      } else {
        result = await executor.execute(resolvedParams).timeout(
              const Duration(seconds: 120),
              onTimeout: () =>
                  {'success': false, 'error': 'Node execution timed out'},
            );
      }

      nodeResults[nodeId] = result;
      nodeStatuses[nodeId] =
          (result['success'] == true) ? NodeStatus.completed : NodeStatus.failed;
    } catch (e) {
      nodeResults[nodeId] = {'success': false, 'error': e.toString()};
      nodeStatuses[nodeId] = NodeStatus.failed;
    }
  }

  /// Resolve {{nodeId.field}} references in parameter values.
  Map<String, dynamic> _resolveNodeParams(
    Map<String, dynamic> params,
    Map<String, Map<String, dynamic>> nodeResults,
    Map<String, dynamic> overrideParams,
  ) {
    final resolved = <String, dynamic>{};
    final pattern = RegExp(r'\{\{(\w+)\.(\w+)\}\}');
    final paramPattern = RegExp(r'\{\{params\.(\w+)\}\}');

    for (final entry in params.entries) {
      final value = entry.value;
      if (value is String) {
        var result = value;

        // Replace {{params.name}} with override parameters
        result = result.replaceAllMapped(paramPattern, (m) {
          final paramName = m.group(1)!;
          return overrideParams[paramName]?.toString() ?? '';
        });

        // Replace {{nodeId.field}} with upstream node results
        result = result.replaceAllMapped(pattern, (m) {
          final nodeId = m.group(1)!;
          final field = m.group(2)!;
          final nodeResult = nodeResults[nodeId];
          if (nodeResult == null) return '';
          return nodeResult[field]?.toString() ?? '';
        });

        resolved[entry.key] = result;
      } else if (value is Map<String, dynamic>) {
        resolved[entry.key] =
            _resolveNodeParams(value, nodeResults, overrideParams);
      } else {
        resolved[entry.key] = value;
      }
    }

    return resolved;
  }

  /// Execute a pipeline starting from a specific node.
  /// Upstream nodes are marked completed with cached results.
  Future<Map<String, dynamic>> executeFromNode(
    PipelineDefinition pipeline,
    String startNodeId,
    Map<String, dynamic> overrideParams,
    Map<String, dynamic> previousResults,
  ) async {
    final stopwatch = Stopwatch()..start();
    final nodeResults = <String, Map<String, dynamic>>{};
    final nodeStatuses = <String, NodeStatus>{};

    // Build adjacency info
    final dependents = <String, List<String>>{};
    final dependencies = <String, Set<String>>{};

    for (final node in pipeline.nodes) {
      dependents[node.id] = [];
      dependencies[node.id] = {};
    }

    for (final edge in pipeline.edges) {
      dependents[edge.sourceNode]?.add(edge.targetNode);
      dependencies[edge.targetNode]?.add(edge.sourceNode);
    }

    // Find all upstream nodes of startNodeId
    final upstream = <String>{};
    void collectUpstream(String nodeId) {
      for (final dep in dependencies[nodeId] ?? {}) {
        if (upstream.add(dep)) {
          collectUpstream(dep);
        }
      }
    }
    collectUpstream(startNodeId);

    // Mark upstream nodes as completed with cached results
    for (final node in pipeline.nodes) {
      if (upstream.contains(node.id)) {
        nodeStatuses[node.id] = NodeStatus.completed;
        if (previousResults.containsKey(node.id)) {
          final prev = previousResults[node.id];
          nodeResults[node.id] = prev is Map<String, dynamic>
              ? prev
              : {'success': true, 'output': prev};
        } else {
          nodeResults[node.id] = {'success': true, 'output': 'cached'};
        }
      } else {
        nodeStatuses[node.id] = NodeStatus.pending;
      }
    }

    // Build in-degree for nodes from startNodeId onwards
    final inDegree = <String, int>{};
    for (final node in pipeline.nodes) {
      if (!upstream.contains(node.id)) {
        int degree = 0;
        for (final dep in dependencies[node.id] ?? {}) {
          if (!upstream.contains(dep)) degree++;
        }
        inDegree[node.id] = degree;
      }
    }

    // Start with nodes that have all upstream deps satisfied
    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }

    int completedCount = 0;
    final totalNodes = inDegree.length;
    bool hasFailed = false;

    while (queue.isNotEmpty) {
      final currentLevel = List<String>.from(queue);
      queue.clear();

      final futures = <Future<void>>[];
      for (final nodeId in currentLevel) {
        futures.add(_executeNode(
          nodeId,
          pipeline,
          nodeResults,
          nodeStatuses,
          overrideParams,
        ));
      }

      await Future.wait(futures);

      for (final nodeId in currentLevel) {
        completedCount++;
        final status = nodeStatuses[nodeId]!;

        _emitProgress(pipeline.id, nodeId, pipeline, nodeStatuses, nodeResults,
            completedCount / totalNodes);

        if (status == NodeStatus.failed) {
          hasFailed = true;
          _skipDownstream(nodeId, dependents, nodeStatuses);
          continue;
        }

        for (final dep in dependents[nodeId]!) {
          if (inDegree.containsKey(dep)) {
            inDegree[dep] = (inDegree[dep] ?? 1) - 1;
            if (inDegree[dep] == 0 &&
                nodeStatuses[dep] != NodeStatus.skipped) {
              queue.add(dep);
            }
          }
        }
      }
    }

    stopwatch.stop();

    return {
      'success': !hasFailed,
      'pipeline_id': pipeline.id,
      'pipeline_name': pipeline.name,
      'node_results': nodeResults,
      'duration_ms': stopwatch.elapsedMilliseconds,
      'nodes_executed': completedCount,
      'nodes_total': totalNodes,
      'started_from': startNodeId,
    };
  }

  /// Check for cycles using DFS.
  bool _hasCycle(
    String nodeId,
    Map<String, List<String>> dependents,
    Set<String> visited,
    Set<String> tempVisited,
  ) {
    if (tempVisited.contains(nodeId)) return true;
    if (visited.contains(nodeId)) return false;

    tempVisited.add(nodeId);
    for (final dep in dependents[nodeId] ?? []) {
      if (_hasCycle(dep, dependents, visited, tempVisited)) return true;
    }
    tempVisited.remove(nodeId);
    visited.add(nodeId);
    return false;
  }

  /// Mark all downstream nodes as skipped.
  void _skipDownstream(
    String nodeId,
    Map<String, List<String>> dependents,
    Map<String, NodeStatus> nodeStatuses,
  ) {
    for (final dep in dependents[nodeId] ?? []) {
      if (nodeStatuses[dep] == NodeStatus.pending) {
        nodeStatuses[dep] = NodeStatus.skipped;
        _skipDownstream(dep, dependents, nodeStatuses);
      }
    }
  }

  /// Emit a progress update.
  void _emitProgress(
    String pipelineId,
    String currentNodeId,
    PipelineDefinition pipeline,
    Map<String, NodeStatus> nodeStatuses,
    Map<String, Map<String, dynamic>> nodeResults,
    double progress,
  ) {
    onProgress?.call({
      'pipeline_id': pipelineId,
      'current_node': currentNodeId,
      'progress': progress,
      'node_status': nodeStatuses.map(
          (k, v) => MapEntry(k, v.name)),
      'node_results': nodeResults,
    });
  }
}
