/// Tray/Menubar Plugin Manager
///
/// Adds plugin management to macOS menubar/system tray.
library;

import 'dart:io';
import 'package:tray_manager/tray_manager.dart';

class TrayPluginMenu {
  /// Build plugin management menu for tray
  static Future<void> buildPluginMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'plugins_header',
          label: '🔌 Plugins',
          disabled: true,
        ),
        MenuItem.separator(),

        // Installed Plugins Section
        MenuItem(
          key: 'installed_header',
          label: 'Installed Plugins',
          disabled: true,
        ),
        MenuItem(
          key: 'twitter_plugin',
          label: '🐦 Twitter API',
          submenu: Menu(items: [
            MenuItem(
              key: 'twitter_start',
              label: 'Start Plugin',
            ),
            MenuItem(
              key: 'twitter_stop',
              label: 'Stop Plugin',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'twitter_config',
              label: 'Configure...',
            ),
            MenuItem(
              key: 'twitter_uninstall',
              label: 'Uninstall',
            ),
          ]),
        ),
        MenuItem(
          key: 'github_plugin',
          label: '🔧 GitHub Automation',
          submenu: Menu(items: [
            MenuItem(
              key: 'github_start',
              label: 'Start Plugin',
            ),
            MenuItem(
              key: 'github_stop',
              label: 'Stop Plugin',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'github_config',
              label: 'Configure...',
            ),
          ]),
        ),
        MenuItem(
          key: 'slack_plugin',
          label: '💬 Slack Integration',
          submenu: Menu(items: [
            MenuItem(
              key: 'slack_start',
              label: 'Start Plugin',
            ),
            MenuItem(
              key: 'slack_stop',
              label: 'Stop Plugin',
            ),
          ]),
        ),
        MenuItem(
          key: 'docker_plugin',
          label: '🐳 Docker Manager',
          submenu: Menu(items: [
            MenuItem(
              key: 'docker_start',
              label: 'Start Plugin',
            ),
            MenuItem(
              key: 'docker_stop',
              label: 'Stop Plugin',
            ),
          ]),
        ),

        MenuItem.separator(),

        // Browse Marketplace
        MenuItem(
          key: 'browse_marketplace',
          label: '🛒 Browse Marketplace...',
        ),

        MenuItem.separator(),

        // Plugin Stats
        MenuItem(
          key: 'plugin_stats',
          label: '📊 4 Installed • 12 Tools',
          disabled: true,
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  /// Handle tray menu item clicks
  static Future<void> handleMenuItemClick(String key) async {
    switch (key) {
      case 'browse_marketplace':
        await _openMarketplace();
        break;

      case 'twitter_start':
        await _startPlugin('twitter-api');
        break;
      case 'twitter_stop':
        await _stopPlugin('twitter-api');
        break;
      case 'twitter_config':
        await _configurePlugin('twitter-api');
        break;
      case 'twitter_uninstall':
        await _uninstallPlugin('twitter-api');
        break;

      case 'github_start':
        await _startPlugin('github-automation');
        break;
      case 'github_stop':
        await _stopPlugin('github-automation');
        break;

      case 'slack_start':
        await _startPlugin('slack-integration');
        break;
      case 'slack_stop':
        await _stopPlugin('slack-integration');
        break;

      case 'docker_start':
        await _startPlugin('docker-manager');
        break;
      case 'docker_stop':
        await _stopPlugin('docker-manager');
        break;
    }
  }

  static Future<void> _openMarketplace() async {
    // Open web UI in browser
    await Process.run('open', ['http://localhost:9877']);
  }

  static Future<void> _startPlugin(String name) async {
    print('Starting plugin: $name');
    // TODO: Call MCP manager to start plugin
  }

  static Future<void> _stopPlugin(String name) async {
    print('Stopping plugin: $name');
    // TODO: Call MCP manager to stop plugin
  }

  static Future<void> _configurePlugin(String name) async {
    // Open configuration UI
    await Process.run('open', ['http://localhost:9877/plugins/$name/config']);
  }

  static Future<void> _uninstallPlugin(String name) async {
    print('Uninstalling plugin: $name');
    // TODO: Confirm and uninstall
  }
}

// Add to imports at top of file
import 'dart:io';
