/// Domain Plugin Adapter
///
/// Bridges the TaskDomain system into OpenCLI's plugin/MCP/tool/router ecosystem:
/// - Each domain becomes an OpenCLIPlugin (callable via PluginRegistry)
/// - Each task type becomes an MCP tool (callable via MCPServerManager)
/// - Each task type becomes a router route (callable via RequestRouter → Unified API)
/// - Each task type becomes a TaskExecutor (callable via MobileTaskHandler)

import 'domain.dart';
import 'domain_registry.dart';
import '../plugins/plugin_sdk.dart';
import '../plugins/mcp_manager.dart';
import '../mobile/mobile_task_handler.dart';

/// Wraps a TaskDomain as an OpenCLIPlugin so it integrates with
/// PluginRegistry, RequestRouter, and the Unified API.
class DomainPluginAdapter extends OpenCLIPlugin {
  final TaskDomain domain;

  DomainPluginAdapter(this.domain);

  @override
  String get id => '@opencli/domain-${domain.id}';

  @override
  String get version => '1.0.0';

  @override
  String get name => domain.name;

  @override
  String get description => domain.description;

  @override
  List<String> get permissions => ['automation'];

  @override
  List<PluginCapability> get capabilities {
    return domain.taskTypes.map((taskType) {
      // Find the Ollama intent for this task type to get parameter info
      final ollamaIntent = domain.ollamaIntents
          .where((i) => i.intentName == taskType)
          .firstOrNull;

      final params = <CapabilityParameter>[];
      if (ollamaIntent != null) {
        for (final entry in ollamaIntent.parameters.entries) {
          params.add(CapabilityParameter(
            name: entry.key,
            type: 'string',
            required: false,
            description: entry.value,
          ));
        }
      }

      return PluginCapability(
        id: taskType,
        name: _taskTypeToName(taskType),
        description:
            ollamaIntent?.description ?? '$taskType via ${domain.name}',
        parameters: params,
      );
    }).toList();
  }

  @override
  Future<PluginResult> execute(
    String capability,
    Map<String, dynamic> params,
  ) async {
    if (!domain.taskTypes.contains(capability)) {
      return PluginResult.failure(
        message: 'Unknown capability: $capability',
        error: PluginError(
          code: 'UNKNOWN_CAPABILITY',
          message: 'Domain ${domain.id} does not handle: $capability',
        ),
      );
    }

    try {
      final result = await domain.executeTask(capability, params);
      final success = result['success'] == true;

      if (success) {
        return PluginResult.success(
          message: result['message'] as String? ?? 'Task completed',
          data: result,
        );
      } else {
        return PluginResult.failure(
          message: result['error'] as String? ?? 'Task failed',
          error: PluginError(
            code: 'TASK_FAILED',
            message: result['error'] as String? ?? 'Unknown error',
          ),
        );
      }
    } catch (e) {
      return PluginResult.failure(
        message: 'Execution error: $e',
        error: PluginError(code: 'EXECUTION_ERROR', message: e.toString()),
      );
    }
  }

  @override
  Future<void> initialize() => domain.initialize();

  @override
  Future<void> dispose() => domain.dispose();

  /// Convert task_type to human-readable name
  String _taskTypeToName(String taskType) {
    return taskType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

/// Wraps a TaskDomain task type as a TaskExecutor for MobileTaskHandler
class DomainTaskExecutor extends TaskExecutor {
  final TaskDomain domain;
  final String taskType;

  DomainTaskExecutor({required this.domain, required this.taskType});

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) {
    return domain.executeTask(taskType, taskData);
  }

  /// Execute with progress reporting for long-running tasks like AI video generation.
  Future<Map<String, dynamic>> executeWithProgress(
    Map<String, dynamic> taskData, {
    ProgressCallback? onProgress,
  }) {
    return domain.executeTaskWithProgress(taskType, taskData,
        onProgress: onProgress);
  }
}

/// Generates MCP tool definitions from domain metadata.
/// These tools can be registered with MCPServerManager so external
/// AI agents (Claude, GPT, etc.) can call domain tasks as MCP tools.
class DomainMcpToolProvider {
  final DomainRegistry registry;

  DomainMcpToolProvider(this.registry);

  /// Generate MCPTool definitions for all domain task types
  List<MCPTool> generateTools() {
    final tools = <MCPTool>[];

    for (final domain in registry.domains) {
      for (final taskType in domain.taskTypes) {
        final ollamaIntent = domain.ollamaIntents
            .where((i) => i.intentName == taskType)
            .firstOrNull;

        final params = <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{},
        };

        if (ollamaIntent != null) {
          for (final entry in ollamaIntent.parameters.entries) {
            (params['properties'] as Map<String, dynamic>)[entry.key] = {
              'type': 'string',
              'description': entry.value,
            };
          }
        }

        tools.add(MCPTool(
          name: 'opencli_${taskType}',
          description: ollamaIntent?.description ??
              '$taskType via ${domain.name} domain',
          parameters: params,
        ));
      }
    }

    return tools;
  }

  /// Generate a JSON Schema-compatible tool list for MCP servers
  List<Map<String, dynamic>> generateToolSchemas() {
    return generateTools()
        .map((tool) => {
              'name': tool.name,
              'description': tool.description,
              'inputSchema': tool.parameters,
            })
        .toList();
  }
}

/// Extension on DomainRegistry to integrate with all OpenCLI subsystems
extension DomainRegistryIntegration on DomainRegistry {
  /// Register all domain task types as TaskExecutors in MobileTaskHandler
  void registerIntoTaskHandler(MobileTaskHandler handler) {
    for (final domain in domains) {
      for (final taskType in domain.taskTypes) {
        handler.registerExecutor(
          taskType,
          DomainTaskExecutor(domain: domain, taskType: taskType),
        );
      }
    }
    print(
        '[DomainRegistry] Registered ${allTaskTypes.length} domain executors into MobileTaskHandler');
  }

  /// Create plugin adapters for all domains
  List<DomainPluginAdapter> createPluginAdapters() {
    return domains.map((d) => DomainPluginAdapter(d)).toList();
  }

  /// Generate MCP tools for all domains
  List<MCPTool> generateMcpTools() {
    return DomainMcpToolProvider(this).generateTools();
  }

  /// Generate tool schemas for MCP protocol
  List<Map<String, dynamic>> generateMcpToolSchemas() {
    return DomainMcpToolProvider(this).generateToolSchemas();
  }

  /// Execute an MCP tool call by name (strips 'opencli_' prefix)
  Future<Map<String, dynamic>> executeMcpTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    // Strip opencli_ prefix if present
    final taskType =
        toolName.startsWith('opencli_') ? toolName.substring(8) : toolName;

    return executeTask(taskType, args);
  }

  /// Get a combined view of all domain capabilities for API discovery
  Map<String, dynamic> getApiDiscovery() {
    return {
      'domains': domains
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'description': d.description,
                'icon': d.icon,
                'color': d.colorHex,
                'platforms': d.supportedPlatforms,
                'capabilities': d.taskTypes.map((taskType) {
                  final intent = d.ollamaIntents
                      .where((i) => i.intentName == taskType)
                      .firstOrNull;
                  return {
                    'id': taskType,
                    'name': _taskTypeToName(taskType),
                    'description': intent?.description ?? taskType,
                    'parameters': intent?.parameters ?? {},
                    'mcp_tool': 'opencli_$taskType',
                    'api_route': '${d.id}.$taskType',
                  };
                }).toList(),
              })
          .toList(),
      'total_domains': domains.length,
      'total_capabilities': allTaskTypes.length,
    };
  }

  String _taskTypeToName(String taskType) {
    return taskType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
