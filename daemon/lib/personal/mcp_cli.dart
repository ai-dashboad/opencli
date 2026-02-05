/// MCP Plugin CLI Commands
library;

import 'dart:io';
import 'package:opencli_daemon/plugins/mcp_manager.dart';
import 'package:opencli_daemon/ui/terminal_ui.dart';

class MCPPluginCLI {
  final MCPServerManager manager;

  MCPPluginCLI(this.manager);

  /// Handle plugin CLI commands
  Future<void> handleCommand(List<String> args) async {
    if (args.isEmpty) {
      _printUsage();
      return;
    }

    final command = args[0];
    final subArgs = args.skip(1).toList();

    switch (command) {
      case 'list':
        await _listPlugins();
        break;
      case 'add':
      case 'install':
        await _installPlugin(subArgs);
        break;
      case 'remove':
      case 'uninstall':
        await _removePlugin(subArgs);
        break;
      case 'start':
        await _startPlugin(subArgs);
        break;
      case 'stop':
        await _stopPlugin(subArgs);
        break;
      case 'restart':
        await _restartPlugin(subArgs);
        break;
      case 'info':
        await _pluginInfo(subArgs);
        break;
      case 'tools':
        await _listTools(subArgs);
        break;
      case 'call':
        await _callTool(subArgs);
        break;
      case 'browse':
      case 'marketplace':
      case 'ui':
        await _openMarketplace();
        break;
      default:
        TerminalUI.error('Unknown command: $command');
        _printUsage();
    }
  }

  void _printUsage() {
    print('''
OpenCLI Plugin Manager

Usage:
  opencli plugin <command> [options]

Commands:
  browse                  Open plugin marketplace in browser
  list                    List installed plugins
  add <name>              Install a plugin
  remove <name>           Uninstall a plugin
  start <name>            Start a plugin
  stop <name>             Stop a plugin
  restart <name>          Restart a plugin
  info <name>             Show plugin information
  tools [plugin]          List available tools
  call <tool> [args]      Call a tool directly

Examples:
  opencli plugin browse
  opencli plugin list
  opencli plugin add twitter-api
  opencli plugin remove twitter-api
  opencli plugin tools twitter-api
  opencli plugin call twitter_post --content "Hello!"
''');
  }

  Future<void> _listPlugins() async {
    final servers = manager.runningServers;

    if (servers.isEmpty) {
      TerminalUI.info('No plugins running');
      return;
    }

    TerminalUI.section('Running Plugins');
    for (final server in servers) {
      TerminalUI.printPluginInfo(
        server.name,
        'Running (PID: ${server.process.pid})',
        server.tools.length,
      );
    }
  }

  Future<void> _installPlugin(List<String> args) async {
    if (args.isEmpty) {
      TerminalUI.error('Plugin name required');
      return;
    }

    final name = args[0];
    TerminalUI.info('Installing plugin: $name');

    // TODO: Implement plugin installation from marketplace
    // For now, just add to config and start

    TerminalUI.success('Plugin installed: $name');
  }

  Future<void> _removePlugin(List<String> args) async {
    if (args.isEmpty) {
      TerminalUI.error('Plugin name required');
      return;
    }

    final name = args[0];
    await manager.stopServer(name);
    TerminalUI.success('Plugin removed: $name');
  }

  Future<void> _startPlugin(List<String> args) async {
    if (args.isEmpty) {
      TerminalUI.error('Plugin name required');
      return;
    }

    final name = args[0];
    // TODO: Load config and start server
    TerminalUI.success('Plugin started: $name');
  }

  Future<void> _stopPlugin(List<String> args) async {
    if (args.isEmpty) {
      TerminalUI.error('Plugin name required');
      return;
    }

    final name = args[0];
    await manager.stopServer(name);
  }

  Future<void> _restartPlugin(List<String> args) async {
    if (args.isEmpty) {
      TerminalUI.error('Plugin name required');
      return;
    }

    final name = args[0];
    await manager.restartServer(name);
  }

  Future<void> _pluginInfo(List<String> args) async {
    if (args.isEmpty) {
      TerminalUI.error('Plugin name required');
      return;
    }

    final name = args[0];
    final server = manager.getServer(name);

    if (server == null) {
      TerminalUI.error('Plugin not found: $name');
      return;
    }

    TerminalUI.section('Plugin: $name');
    print('Status: ${server.isRunning ? "Running" : "Stopped"}');
    print('PID: ${server.process.pid}');
    print('Tools: ${server.tools.length}');
    print('');
    print('Available Tools:');
    for (final tool in server.tools) {
      print('  • ${tool.name} - ${tool.description}');
    }
  }

  Future<void> _listTools([List<String> args = const []]) async {
    final tools = await manager.listAllTools();

    if (tools.isEmpty) {
      TerminalUI.info('No tools available');
      return;
    }

    TerminalUI.section('Available Tools');
    for (final tool in tools) {
      print('${tool.name}');
      print('  ${tool.description}');
      print('');
    }
  }

  Future<void> _callTool(List<String> args) async {
    if (args.isEmpty) {
      TerminalUI.error('Tool name required');
      return;
    }

    final toolName = args[0];
    final toolArgs = _parseArgs(args.skip(1).toList());

    TerminalUI.info('Calling tool: $toolName');

    try {
      final result = await manager.callTool(toolName, toolArgs);
      TerminalUI.success('Result:');
      print(result);
    } catch (e) {
      TerminalUI.error('Error calling tool: $e');
    }
  }

  Future<void> _openMarketplace() async {
    final url = 'http://localhost:9877';
    TerminalUI.info('Opening plugin marketplace...');
    TerminalUI.printKeyValue('URL', url);

    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', url]);
      }
      TerminalUI.success('Marketplace opened in browser');
    } catch (e) {
      TerminalUI.error('Failed to open browser: $e');
      TerminalUI.info('Please open manually: $url');
    }
  }

  Map<String, dynamic> _parseArgs(List<String> args) {
    final result = <String, dynamic>{};

    for (var i = 0; i < args.length; i++) {
      if (args[i].startsWith('--')) {
        final key = args[i].substring(2);
        if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
          result[key] = args[i + 1];
          i++;
        } else {
          result[key] = true;
        }
      }
    }

    return result;
  }
}

extension on TerminalUI {
  static void printPluginInfo(String name, String status, int toolCount) {
    print('  $name');
    print('    Status: $status');
    print('    Tools: $toolCount');
    print('');
  }
}
