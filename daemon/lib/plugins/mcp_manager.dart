/// MCP Server Manager
///
/// Manages Model Context Protocol (MCP) servers for plugins.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// MCP Server Manager
class MCPServerManager {
  final String configPath;
  final Map<String, MCPServer> _servers = {};
  final Map<String, Process> _processes = {};

  MCPServerManager({required this.configPath});

  /// Initialize and start all configured MCP servers
  Future<void> initialize() async {
    final config = await _loadConfig();
    for (final entry in config.entries) {
      await startServer(entry.key, entry.value);
    }
  }

  /// Load MCP server configuration
  Future<Map<String, MCPServerConfig>> _loadConfig() async {
    final file = File(configPath);
    if (!await file.exists()) {
      return {};
    }

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final mcpServers = json['mcpServers'] as Map<String, dynamic>? ?? {};

    final configs = <String, MCPServerConfig>{};
    for (final entry in mcpServers.entries) {
      configs[entry.key] = MCPServerConfig.fromJson(entry.value);
    }
    return configs;
  }

  /// Start an MCP server
  Future<void> startServer(String name, MCPServerConfig config) async {
    if (_processes.containsKey(name)) {
      print('MCP server already running: $name');
      return;
    }

    try {
      final process = await Process.start(
        config.command,
        config.args,
        environment: config.env,
        workingDirectory: config.workingDirectory,
      );

      _processes[name] = process;
      _servers[name] = MCPServer(
        name: name,
        config: config,
        process: process,
      );

      // Listen to stdout/stderr
      process.stdout.transform(utf8.decoder).listen((data) {
        print('[$name] $data');
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        print('[$name ERROR] $data');
      });

      // Monitor process exit
      process.exitCode.then((code) {
        print('[$name] Exited with code $code');
        _servers[name]?.markStopped();
        _processes.remove(name);
        _servers.remove(name);
      });

      print('✅ Started MCP server: $name');
    } catch (e) {
      print('❌ Failed to start MCP server $name: $e');
    }
  }

  /// Stop an MCP server
  Future<void> stopServer(String name) async {
    final process = _processes[name];
    if (process == null) return;

    _servers[name]?.markStopped();
    process.kill();
    await process.exitCode;
    _processes.remove(name);
    _servers.remove(name);
    print('🛑 Stopped MCP server: $name');
  }

  /// Restart an MCP server
  Future<void> restartServer(String name) async {
    final server = _servers[name];
    if (server == null) return;

    await stopServer(name);
    await Future.delayed(Duration(seconds: 1));
    await startServer(name, server.config);
  }

  /// Get all running servers
  List<MCPServer> get runningServers => _servers.values.toList();

  /// Check if server is running
  bool isRunning(String name) => _processes.containsKey(name);

  /// Stop all servers
  Future<void> stopAll() async {
    final names = _processes.keys.toList();
    for (final name in names) {
      await stopServer(name);
    }
  }

  /// Get server info
  MCPServer? getServer(String name) => _servers[name];

  /// List available tools from all servers
  Future<List<MCPTool>> listAllTools() async {
    final tools = <MCPTool>[];
    for (final server in _servers.values) {
      tools.addAll(server.tools);
    }
    return tools;
  }

  /// Find tool by name
  MCPTool? findTool(String toolName) {
    for (final server in _servers.values) {
      final tool = server.tools.firstWhere(
        (t) => t.name == toolName,
        orElse: () => MCPTool(
          name: '',
          description: '',
          parameters: {},
        ),
      );
      if (tool.name.isNotEmpty) return tool;
    }
    return null;
  }

  /// Call a tool on an MCP server
  Future<Map<String, dynamic>> callTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    // Find which server has this tool
    MCPServer? targetServer;
    for (final server in _servers.values) {
      if (server.tools.any((t) => t.name == toolName)) {
        targetServer = server;
        break;
      }
    }

    if (targetServer == null) {
      throw Exception('Tool not found: $toolName');
    }

    // Send JSON-RPC request to MCP server
    final request = {
      'jsonrpc': '2.0',
      'id': DateTime.now().millisecondsSinceEpoch,
      'method': 'tools/call',
      'params': {
        'name': toolName,
        'arguments': args,
      },
    };

    // TODO: Implement actual JSON-RPC communication
    // For now, return mock response
    return {
      'success': true,
      'result': 'Tool executed: $toolName',
    };
  }
}

/// MCP Server Configuration
class MCPServerConfig {
  final String command;
  final List<String> args;
  final Map<String, String> env;
  final String? workingDirectory;

  MCPServerConfig({
    required this.command,
    required this.args,
    this.env = const {},
    this.workingDirectory,
  });

  factory MCPServerConfig.fromJson(Map<String, dynamic> json) {
    return MCPServerConfig(
      command: json['command'] as String,
      args: (json['args'] as List?)?.map((e) => e.toString()).toList() ?? [],
      env: (json['env'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      workingDirectory: json['workingDirectory'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'command': command,
        'args': args,
        'env': env,
        'workingDirectory': workingDirectory,
      };
}

/// MCP Server instance
class MCPServer {
  final String name;
  final MCPServerConfig config;
  final Process process;
  final List<MCPTool> tools;
  bool _isRunning = true;

  MCPServer({
    required this.name,
    required this.config,
    required this.process,
    this.tools = const [],
  });

  bool get isRunning => _isRunning;

  void markStopped() {
    _isRunning = false;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'running': isRunning,
        'pid': process.pid,
        'tools': tools.map((t) => t.toJson()).toList(),
      };
}

/// MCP Tool definition
class MCPTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  MCPTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  factory MCPTool.fromJson(Map<String, dynamic> json) {
    return MCPTool(
      name: json['name'] as String,
      description: json['description'] as String,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters,
      };
}
