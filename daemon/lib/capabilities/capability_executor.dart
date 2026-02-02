import 'dart:async';
import 'capability_schema.dart';
import 'capability_registry.dart';

/// Result of executing a capability
class CapabilityExecutionResult {
  final String capabilityId;
  final bool success;
  final Map<String, dynamic> result;
  final String? error;
  final Duration duration;
  final List<WorkflowStepResult> stepResults;

  const CapabilityExecutionResult({
    required this.capabilityId,
    required this.success,
    required this.result,
    this.error,
    required this.duration,
    this.stepResults = const [],
  });

  Map<String, dynamic> toJson() => {
    'capabilityId': capabilityId,
    'success': success,
    'result': result,
    'error': error,
    'durationMs': duration.inMilliseconds,
    'steps': stepResults.map((s) => s.toJson()).toList(),
  };
}

/// Result of a single workflow step
class WorkflowStepResult {
  final String action;
  final bool success;
  final Map<String, dynamic> result;
  final String? error;
  final Duration duration;

  const WorkflowStepResult({
    required this.action,
    required this.success,
    required this.result,
    this.error,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
    'action': action,
    'success': success,
    'result': result,
    'error': error,
    'durationMs': duration.inMilliseconds,
  };
}

/// Execution context for a capability workflow
class ExecutionContext {
  /// Input parameters
  final Map<String, dynamic> parameters;

  /// Variables from workflow steps (stored results)
  final Map<String, dynamic> variables;

  /// Step results
  final List<WorkflowStepResult> stepResults;

  ExecutionContext({
    required this.parameters,
  }) : variables = {...parameters},
       stepResults = [];

  /// Resolve a template string with variables
  String resolveTemplate(String template) {
    var result = template;

    // Replace ${variable} patterns
    final pattern = RegExp(r'\$\{(\w+)\}');
    result = result.replaceAllMapped(pattern, (match) {
      final varName = match.group(1)!;
      final value = variables[varName];
      return value?.toString() ?? '';
    });

    return result;
  }

  /// Resolve params map with variable substitution
  Map<String, dynamic> resolveParams(Map<String, dynamic> params) {
    final resolved = <String, dynamic>{};

    params.forEach((key, value) {
      if (value is String) {
        resolved[key] = resolveTemplate(value);
      } else if (value is Map<String, dynamic>) {
        resolved[key] = resolveParams(value);
      } else if (value is List) {
        resolved[key] = value.map((v) {
          if (v is String) return resolveTemplate(v);
          return v;
        }).toList();
      } else {
        resolved[key] = value;
      }
    });

    return resolved;
  }

  /// Store a result from a workflow step
  void storeResult(String name, dynamic value) {
    variables[name] = value;
  }

  /// Add a step result
  void addStepResult(WorkflowStepResult result) {
    stepResults.add(result);
  }
}

/// Function type for action handlers
typedef ActionHandler = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> params,
  ExecutionContext context,
);

/// Executes capability workflows
class CapabilityExecutor {
  final CapabilityRegistry _registry;

  /// Registered action handlers
  final Map<String, ActionHandler> _handlers = {};

  /// Execution timeout
  final Duration defaultTimeout;

  CapabilityExecutor({
    required CapabilityRegistry registry,
    this.defaultTimeout = const Duration(seconds: 30),
  }) : _registry = registry;

  /// Register an action handler
  void registerHandler(String action, ActionHandler handler) {
    _handlers[action] = handler;
    print('[CapabilityExecutor] Registered handler: $action');
  }

  /// Unregister an action handler
  void unregisterHandler(String action) {
    _handlers.remove(action);
  }

  /// Check if a handler exists
  bool hasHandler(String action) => _handlers.containsKey(action);

  /// Execute a capability by ID
  Future<CapabilityExecutionResult> execute(
    String capabilityId,
    Map<String, dynamic> parameters,
  ) async {
    final startTime = DateTime.now();

    try {
      // Get capability
      final capability = await _registry.get(capabilityId);
      if (capability == null) {
        return CapabilityExecutionResult(
          capabilityId: capabilityId,
          success: false,
          result: {},
          error: 'Capability not found: $capabilityId',
          duration: DateTime.now().difference(startTime),
        );
      }

      // Validate parameters
      final validationErrors = capability.validateParameters(parameters);
      if (validationErrors.isNotEmpty) {
        return CapabilityExecutionResult(
          capabilityId: capabilityId,
          success: false,
          result: {},
          error: 'Parameter validation failed: ${validationErrors.join(', ')}',
          duration: DateTime.now().difference(startTime),
        );
      }

      // Apply default values
      final fullParams = <String, dynamic>{...parameters};
      for (final param in capability.parameters) {
        if (!fullParams.containsKey(param.name) && param.defaultValue != null) {
          fullParams[param.name] = param.defaultValue;
        }
      }

      // Create execution context
      final context = ExecutionContext(parameters: fullParams);

      // Execute workflow
      Map<String, dynamic> lastResult = {};

      for (final action in capability.workflow) {
        // Check condition
        if (action.condition != null) {
          final shouldRun = _evaluateCondition(action.condition!, context);
          if (!shouldRun) {
            continue;
          }
        }

        // Execute action
        final stepResult = await _executeAction(action, context);
        context.addStepResult(stepResult);

        if (!stepResult.success) {
          // Handle error
          if (action.onError == 'continue') {
            continue;
          } else if (action.onError == 'skip') {
            // Skip remaining steps but don't fail
            break;
          } else {
            // Fail the entire execution
            return CapabilityExecutionResult(
              capabilityId: capabilityId,
              success: false,
              result: lastResult,
              error: 'Step ${action.action} failed: ${stepResult.error}',
              duration: DateTime.now().difference(startTime),
              stepResults: context.stepResults,
            );
          }
        }

        lastResult = stepResult.result;

        // Store result if requested
        if (action.storeResult != null) {
          context.storeResult(action.storeResult!, stepResult.result);
        }

        // Also store with action name as default
        context.storeResult('${action.action}_result', stepResult.result);
      }

      return CapabilityExecutionResult(
        capabilityId: capabilityId,
        success: true,
        result: lastResult,
        duration: DateTime.now().difference(startTime),
        stepResults: context.stepResults,
      );
    } catch (e, stackTrace) {
      return CapabilityExecutionResult(
        capabilityId: capabilityId,
        success: false,
        result: {},
        error: 'Execution error: $e\n$stackTrace',
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Execute a single workflow action
  Future<WorkflowStepResult> _executeAction(
    WorkflowAction action,
    ExecutionContext context,
  ) async {
    final startTime = DateTime.now();

    try {
      // Get handler
      final handler = _handlers[action.action];
      if (handler == null) {
        return WorkflowStepResult(
          action: action.action,
          success: false,
          result: {},
          error: 'No handler for action: ${action.action}',
          duration: DateTime.now().difference(startTime),
        );
      }

      // Resolve parameters
      final resolvedParams = context.resolveParams(action.params);

      // Execute with timeout
      final timeout = action.timeout ?? defaultTimeout;
      final result = await handler(resolvedParams, context)
          .timeout(timeout, onTimeout: () {
            throw TimeoutException('Action timed out after ${timeout.inSeconds}s');
          });

      return WorkflowStepResult(
        action: action.action,
        success: true,
        result: result,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return WorkflowStepResult(
        action: action.action,
        success: false,
        result: {},
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Evaluate a condition expression
  bool _evaluateCondition(String condition, ExecutionContext context) {
    // Simple condition evaluation
    // Supports: ${var} == value, ${var} != value, ${var}

    final template = context.resolveTemplate(condition);

    // Check for comparison operators
    if (template.contains('==')) {
      final parts = template.split('==').map((s) => s.trim()).toList();
      return parts[0] == parts[1];
    }

    if (template.contains('!=')) {
      final parts = template.split('!=').map((s) => s.trim()).toList();
      return parts[0] != parts[1];
    }

    // Truthy check
    return template.isNotEmpty &&
           template != 'false' &&
           template != 'null' &&
           template != '0';
  }

  /// Get execution statistics
  Map<String, dynamic> getStats() {
    return {
      'registeredHandlers': _handlers.keys.toList(),
      'handlerCount': _handlers.length,
      'defaultTimeoutSeconds': defaultTimeout.inSeconds,
    };
  }
}
