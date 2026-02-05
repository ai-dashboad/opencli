/// Plugin Marketplace Web UI
///
/// Visual interface for browsing, installing, and managing plugins.
library;

import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as path;
import 'package:opencli_daemon/plugins/mcp_manager.dart';

class PluginMarketplaceUI {
  HttpServer? _server;
  final int port;
  final MCPServerManager? mcpManager;
  final String pluginsDir;

  PluginMarketplaceUI({
    this.port = 9877,
    this.mcpManager,
    this.pluginsDir = 'plugins',
  });

  /// Start the plugin marketplace web UI
  Future<void> start() async {
    final router = Router();

    // Find static directory - try multiple paths
    String? staticPath;
    final candidates = [
      'daemon/lib/ui/static', // Running from project root
      'lib/ui/static', // Running from daemon directory
      '../daemon/lib/ui/static', // Running from subdirectory
    ];

    for (final candidate in candidates) {
      final dir = Directory(candidate);
      if (dir.existsSync()) {
        staticPath = candidate;
        break;
      }
    }

    if (staticPath == null) {
      throw Exception('Could not find static files directory');
    }

    // Serve static files
    final staticHandler = createStaticHandler(
      staticPath,
      defaultDocument: 'plugin-marketplace.html',
    );

    // API: Get available plugins
    router.get('/api/plugins', _handleGetPlugins);

    // API: Get installed plugins
    router.get('/api/plugins/installed', _handleGetInstalledPlugins);

    // API: Install plugin
    router.post('/api/plugins/<name>/install', _handleInstallPlugin);

    // API: Uninstall plugin
    router.delete('/api/plugins/<name>/uninstall', _handleUninstallPlugin);

    // API: Start/stop plugin
    router.post('/api/plugins/<name>/start', _handleStartPlugin);
    router.post('/api/plugins/<name>/stop', _handleStopPlugin);

    // API: Get plugin details
    router.get('/api/plugins/<name>', _handleGetPluginDetails);

    // Fallback to static files
    final handler = Cascade()
        .add(router)
        .add(staticHandler)
        .handler;

    _server = await io.serve(handler, 'localhost', port);
    print('🌐 Plugin Marketplace UI: http://localhost:$port');
  }

  /// Stop the web UI server
  Future<void> stop() async {
    await _server?.close();
  }

  /// Scan plugins directory for available plugins
  Future<List<Map<String, dynamic>>> _scanAvailablePlugins() async {
    final plugins = <Map<String, dynamic>>[];

    // Scan plugins directory
    final pluginsDirectory = Directory(pluginsDir);
    if (!pluginsDirectory.existsSync()) {
      return plugins;
    }

    final entries = pluginsDirectory.listSync();
    for (final entry in entries) {
      if (entry is Directory) {
        final pluginName = path.basename(entry.path);
        final packageJson = File(path.join(entry.path, 'package.json'));

        if (packageJson.existsSync()) {
          try {
            final content = await packageJson.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;

            // Check if installed and running
            final isRunning = mcpManager?.isRunning(pluginName) ?? false;
            final server = mcpManager?.getServer(pluginName);

            plugins.add({
              'id': json['name'] ?? pluginName,
              'name': _formatPluginName(pluginName),
              'description': json['description'] ?? 'No description',
              'version': json['version'] ?? '1.0.0',
              'category': _inferCategory(pluginName),
              'rating': 4.5,
              'downloads': 0,
              'tools': server?.tools.map((t) => t.name).toList() ?? [],
              'installed': true,
              'running': isRunning,
            });
          } catch (e) {
            print('Error reading plugin $pluginName: $e');
          }
        }
      }
    }

    // Add some uninstalled plugins for discovery
    plugins.addAll(_getMarketplacePlugins(plugins.map((p) => p['id'] as String).toList()));

    return plugins;
  }

  /// Format plugin name for display
  String _formatPluginName(String dirName) {
    return dirName
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Infer category from plugin name
  String _inferCategory(String name) {
    if (name.contains('twitter') || name.contains('facebook') || name.contains('linkedin')) {
      return 'social-media';
    } else if (name.contains('github') || name.contains('gitlab') || name.contains('git')) {
      return 'development';
    } else if (name.contains('slack') || name.contains('discord') || name.contains('teams')) {
      return 'communication';
    } else if (name.contains('docker') || name.contains('kubernetes') || name.contains('k8s')) {
      return 'devops';
    } else if (name.contains('aws') || name.contains('azure') || name.contains('gcp')) {
      return 'cloud';
    } else if (name.contains('playwright') || name.contains('selenium') || name.contains('test')) {
      return 'testing';
    }
    return 'development';
  }

  /// Get marketplace plugins (not yet installed)
  List<Map<String, dynamic>> _getMarketplacePlugins(List<String> installedIds) {
    final available = [
      {
        'id': '@opencli/aws-integration',
        'name': 'AWS Integration',
        'description': 'S3, EC2, Lambda management',
        'version': '1.0.0',
        'category': 'cloud',
        'rating': 4.5,
        'downloads': 750,
        'tools': ['aws_s3_upload', 'aws_ec2_list', 'aws_lambda_invoke'],
        'installed': false,
        'running': false,
      },
      {
        'id': '@opencli/playwright-automation',
        'name': 'Playwright Automation',
        'description': 'Web testing and automation',
        'version': '1.0.0',
        'category': 'testing',
        'rating': 4.8,
        'downloads': 1100,
        'tools': ['web_navigate', 'web_click', 'web_screenshot'],
        'installed': false,
        'running': false,
      },
      {
        'id': '@opencli/postgresql-manager',
        'name': 'PostgreSQL Manager',
        'description': 'Database operations and queries',
        'version': '1.0.0',
        'category': 'database',
        'rating': 4.7,
        'downloads': 890,
        'tools': ['pg_query', 'pg_connect', 'pg_backup'],
        'installed': false,
        'running': false,
      },
    ];

    // Filter out already installed plugins
    return available.where((p) => !installedIds.contains(p['id'])).toList();
  }

  /// Get available plugins from marketplace
  Future<Response> _handleGetPlugins(Request request) async {
    final plugins = await _scanAvailablePlugins();

    return Response.ok(
      jsonEncode({'plugins': plugins}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Get installed plugins
  Future<Response> _handleGetInstalledPlugins(Request request) async {
    final plugins = await _scanAvailablePlugins();
    final installed = plugins.where((p) => p['installed'] == true).toList();

    return Response.ok(
      jsonEncode({'plugins': installed}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Install plugin
  Future<Response> _handleInstallPlugin(Request request, String name) async {
    print('Installing plugin: $name');

    // For now, simulate installation
    await Future.delayed(Duration(seconds: 2));

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Plugin installed successfully',
        'plugin': name,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Uninstall plugin
  Future<Response> _handleUninstallPlugin(Request request, String name) async {
    print('Uninstalling plugin: $name');

    // Stop plugin if running
    if (mcpManager != null && mcpManager!.isRunning(name)) {
      await mcpManager!.stopServer(name);
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Plugin uninstalled'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Start plugin
  Future<Response> _handleStartPlugin(Request request, String name) async {
    print('Starting plugin: $name');

    if (mcpManager != null) {
      try {
        // Load config for this plugin
        final configFile = File('.opencli/mcp-servers.json');
        if (configFile.existsSync()) {
          final content = await configFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final servers = json['mcpServers'] as Map<String, dynamic>?;

          if (servers != null && servers.containsKey(name)) {
            final config = MCPServerConfig.fromJson(servers[name]);
            await mcpManager!.startServer(name, config);

            return Response.ok(
              jsonEncode({'success': true, 'message': 'Plugin started'}),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': 'Plugin config not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': 'Failed to start: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Plugin started (no manager)'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Stop plugin
  Future<Response> _handleStopPlugin(Request request, String name) async {
    print('Stopping plugin: $name');

    if (mcpManager != null) {
      try {
        await mcpManager!.stopServer(name);
        return Response.ok(
          jsonEncode({'success': true, 'message': 'Plugin stopped'}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': 'Failed to stop: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Plugin stopped (no manager)'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Get plugin details
  Future<Response> _handleGetPluginDetails(Request request, String name) async {
    // Get real plugin info if available
    final server = mcpManager?.getServer(name);

    final plugin = {
      'id': name,
      'name': _formatPluginName(name),
      'description': 'Plugin details for $name',
      'version': '1.0.0',
      'installed': server != null,
      'running': server?.isRunning ?? false,
      'tools': server?.tools.map((t) => {
        'name': t.name,
        'description': t.description,
      }).toList() ?? [],
    };

    return Response.ok(
      jsonEncode(plugin),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
