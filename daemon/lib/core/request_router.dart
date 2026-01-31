import 'package:opencli_daemon/plugins/plugin_manager.dart';
import 'package:opencli_daemon/ipc/ipc_protocol.dart';

class RequestRouter {
  final PluginManager pluginManager;
  int _totalRequests = 0;

  RequestRouter(this.pluginManager);

  int get totalRequests => _totalRequests;

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

  Future<String> _handleSystemCommand(List<String> parts, List<dynamic> params) async {
    if (parts.isEmpty) {
      throw Exception('Missing system command');
    }

    switch (parts[0]) {
      case 'health':
        return 'OK';
      case 'plugins':
        return pluginManager.listPlugins().join(', ');
      case 'version':
        return '0.1.0';
      default:
        throw Exception('Unknown system command: ${parts[0]}');
    }
  }

  Future<String> _handleChat(List<dynamic> params) async {
    if (params.isEmpty) {
      return 'Hello! How can I help you?';
    }

    // TODO: Integrate with AI module
    return 'Echo: ${params.join(" ")}';
  }
}
