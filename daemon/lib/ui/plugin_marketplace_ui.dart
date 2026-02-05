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

class PluginMarketplaceUI {
  HttpServer? _server;
  final int port;

  PluginMarketplaceUI({this.port = 9877});

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

  /// Get available plugins from marketplace
  Future<Response> _handleGetPlugins(Request request) async {
    final plugins = [
      {
        'id': '@opencli/twitter-api',
        'name': 'Twitter API',
        'description': 'Post tweets, monitor keywords, auto-reply',
        'version': '1.0.0',
        'category': 'social-media',
        'rating': 4.8,
        'downloads': 1250,
        'tools': ['twitter_post', 'twitter_search', 'twitter_monitor', 'twitter_reply'],
        'installed': true,
        'running': false,
      },
      {
        'id': '@opencli/github-automation',
        'name': 'GitHub Automation',
        'description': 'Releases, PRs, Issues, Actions',
        'version': '1.0.0',
        'category': 'development',
        'rating': 4.9,
        'downloads': 2100,
        'tools': ['github_create_release', 'github_create_pr', 'github_create_issue'],
        'installed': true,
        'running': false,
      },
      {
        'id': '@opencli/slack-integration',
        'name': 'Slack Integration',
        'description': 'Send messages, create channels',
        'version': '1.0.0',
        'category': 'communication',
        'rating': 4.7,
        'downloads': 890,
        'tools': ['slack_send_message'],
        'installed': true,
        'running': false,
      },
      {
        'id': '@opencli/docker-manager',
        'name': 'Docker Manager',
        'description': 'Manage containers and images',
        'version': '1.0.0',
        'category': 'devops',
        'rating': 4.6,
        'downloads': 1500,
        'tools': ['docker_list_containers', 'docker_run'],
        'installed': true,
        'running': false,
      },
      // Add more plugins...
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
    ];

    return Response.ok(
      jsonEncode({'plugins': plugins}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Get installed plugins
  Future<Response> _handleGetInstalledPlugins(Request request) async {
    // TODO: Get from actual MCP manager
    final plugins = [
      {
        'id': '@opencli/twitter-api',
        'name': 'Twitter API',
        'running': false,
        'tools': 4,
      },
      {
        'id': '@opencli/github-automation',
        'name': 'GitHub Automation',
        'running': false,
        'tools': 5,
      },
    ];

    return Response.ok(
      jsonEncode({'plugins': plugins}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Install plugin
  Future<Response> _handleInstallPlugin(Request request, String name) async {
    // TODO: Implement actual installation
    print('Installing plugin: $name');

    await Future.delayed(Duration(seconds: 2)); // Simulate installation

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
    return Response.ok(
      jsonEncode({'success': true, 'message': 'Plugin uninstalled'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Start plugin
  Future<Response> _handleStartPlugin(Request request, String name) async {
    print('Starting plugin: $name');
    return Response.ok(
      jsonEncode({'success': true, 'message': 'Plugin started'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Stop plugin
  Future<Response> _handleStopPlugin(Request request, String name) async {
    print('Stopping plugin: $name');
    return Response.ok(
      jsonEncode({'success': true, 'message': 'Plugin stopped'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Get plugin details
  Future<Response> _handleGetPluginDetails(Request request, String name) async {
    final plugin = {
      'id': name,
      'name': 'Twitter API',
      'description': 'Full-featured Twitter/X automation plugin',
      'version': '1.0.0',
      'author': 'OpenCLI Team',
      'license': 'MIT',
      'category': 'social-media',
      'rating': 4.8,
      'downloads': 1250,
      'installed': true,
      'running': false,
      'tools': [
        {'name': 'twitter_post', 'description': 'Post a tweet'},
        {'name': 'twitter_search', 'description': 'Search tweets'},
        {'name': 'twitter_monitor', 'description': 'Monitor keywords'},
        {'name': 'twitter_reply', 'description': 'Reply to tweets'},
      ],
      'configuration': [
        {'key': 'TWITTER_API_KEY', 'required': true, 'secret': true},
        {'key': 'TWITTER_API_SECRET', 'required': true, 'secret': true},
      ],
    };

    return Response.ok(
      jsonEncode(plugin),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
