import 'package:opencli_daemon/core/config.dart';
import 'package:opencli_daemon/ui/terminal_ui.dart';

class PluginManager {
  final Config config;
  final Map<String, dynamic> _loadedPlugins = {};

  PluginManager(this.config);

  int get loadedCount => _loadedPlugins.length;

  Future<void> loadAll() async {
    final enabledPlugins = config.plugins['enabled'] as List? ?? [];

    if (enabledPlugins.isEmpty) {
      TerminalUI.info('No plugins to load', prefix: '  ℹ');
      return;
    }

    for (final pluginName in enabledPlugins) {
      await _loadPlugin(pluginName);
    }

    TerminalUI.success('Loaded ${_loadedPlugins.length} plugin${_loadedPlugins.length == 1 ? '' : 's'}', prefix: '  ✓');
  }

  Future<void> unloadAll() async {
    TerminalUI.info('Unloading plugins...', prefix: '🔌');
    _loadedPlugins.clear();
  }

  Future<void> reload(Config newConfig) async {
    await unloadAll();
    await loadAll();
  }

  Future<void> _loadPlugin(String pluginName) async {
    // TODO: Implement dynamic plugin loading
    TerminalUI.printPluginLoaded(pluginName);
    _loadedPlugins[pluginName] = {};
  }

  Future<String> execute(
    String pluginName,
    String action,
    List<dynamic> params,
    Map<String, dynamic> context,
  ) async {
    if (!_loadedPlugins.containsKey(pluginName)) {
      throw Exception('Plugin not found: $pluginName');
    }

    // TODO: Execute plugin action
    return 'Plugin $pluginName executed action: $action';
  }

  List<String> listPlugins() {
    return _loadedPlugins.keys.toList();
  }
}
