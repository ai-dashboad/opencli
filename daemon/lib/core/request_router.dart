import 'dart:convert';
import 'package:opencli_daemon/plugins/plugin_manager.dart';
import 'package:opencli_daemon/ipc/ipc_protocol.dart';
import 'package:opencli_daemon/domains/domain_registry.dart';
import 'package:opencli_daemon/domains/domain_plugin_adapter.dart';

class RequestRouter {
  final PluginManager pluginManager;
  DomainRegistry? _domainRegistry;
  int _totalRequests = 0;

  RequestRouter(this.pluginManager);

  int get totalRequests => _totalRequests;

  /// Set the domain registry for domain-based routing
  void setDomainRegistry(DomainRegistry registry) {
    _domainRegistry = registry;
  }

  Future<String> route(IpcRequest request) async {
    _totalRequests++;

    final parts = request.method.split('.');

    if (parts.isEmpty) {
      throw Exception('Invalid method format');
    }

    // System commands
    if (parts[0] == 'system') {
      return await _handleSystemCommand(parts.sublist(1), request.params);
    }

    // Domain commands: domain.taskType (e.g., music.music_play, timer.timer_set)
    if (parts.length >= 2 && _domainRegistry != null) {
      final domainId = parts[0];
      final domain = _domainRegistry!.getDomain(domainId);
      if (domain != null) {
        final taskType = parts.sublist(1).join('_');
        final params = _extractParams(request.params);
        final result = await _domainRegistry!.executeTask(taskType, params);
        return jsonEncode(result);
      }
    }

    // Domain shorthand: just taskType directly (e.g., music_play, timer_set)
    if (_domainRegistry != null && _domainRegistry!.handlesTaskType(parts[0])) {
      final params = _extractParams(request.params);
      final result = await _domainRegistry!.executeTask(parts[0], params);
      return jsonEncode(result);
    }

    // MCP tool calls: mcp.toolName (e.g., mcp.opencli_music_play)
    if (parts[0] == 'mcp' && parts.length >= 2 && _domainRegistry != null) {
      final toolName = parts.sublist(1).join('_');
      final params = _extractParams(request.params);
      final result = await _domainRegistry!.executeMcpTool(toolName, params);
      return jsonEncode(result);
    }

    // Domain discovery: domains.list / domains.stats / domains.tools
    if (parts[0] == 'domains') {
      return await _handleDomainsCommand(parts.sublist(1));
    }

    // Plugin commands: plugin.action
    if (parts.length >= 2) {
      final pluginName = parts[0];
      final action = parts.sublist(1).join('.');

      return await pluginManager.execute(
        pluginName,
        action,
        request.params,
        request.context,
      );
    }

    // Default: treat as chat command
    if (parts[0] == 'chat') {
      return await _handleChat(request.params);
    }

    throw Exception('Unknown method: ${request.method}');
  }

  /// Extract params map from IPC request params list
  Map<String, dynamic> _extractParams(List<dynamic> params) {
    if (params.isEmpty) return <String, dynamic>{};
    if (params.first is Map) {
      return Map<String, dynamic>.from(params.first as Map);
    }
    return <String, dynamic>{};
  }

  Future<String> _handleSystemCommand(List<String> parts, List<dynamic> params) async {
    if (parts.isEmpty) {
      throw Exception('Missing system command');
    }

    switch (parts[0]) {
      case 'health':
        return 'OK';
      case 'plugins':
        final plugins = pluginManager.listPlugins();
        // Include domain plugins in listing
        if (_domainRegistry != null) {
          for (final domain in _domainRegistry!.domains) {
            plugins.add('@opencli/domain-${domain.id}');
          }
        }
        return plugins.join(', ');
      case 'version':
        return '0.2.0';
      case 'domains':
        if (_domainRegistry != null) {
          return jsonEncode(_domainRegistry!.getApiDiscovery());
        }
        return jsonEncode({'domains': [], 'total_domains': 0});
      case 'tools':
        if (_domainRegistry != null) {
          return jsonEncode(_domainRegistry!.generateMcpToolSchemas());
        }
        return jsonEncode([]);
      default:
        throw Exception('Unknown system command: ${parts[0]}');
    }
  }

  /// Handle domains.* commands for discovery and management
  Future<String> _handleDomainsCommand(List<String> parts) async {
    if (_domainRegistry == null) {
      return jsonEncode({'error': 'Domain registry not initialized'});
    }

    if (parts.isEmpty || parts[0] == 'list') {
      return jsonEncode(_domainRegistry!.getApiDiscovery());
    }

    if (parts[0] == 'stats') {
      return jsonEncode(_domainRegistry!.getStats());
    }

    if (parts[0] == 'tools') {
      return jsonEncode(_domainRegistry!.generateMcpToolSchemas());
    }

    throw Exception('Unknown domains command: ${parts.join(".")}');
  }

  Future<String> _handleChat(List<dynamic> params) async {
    if (params.isEmpty) {
      return 'Hello! How can I help you?';
    }

    // TODO: Integrate with AI module
    return 'Echo: ${params.join(" ")}';
  }
}
