import 'package:opencli_daemon/core/config.dart';

class PluginManager {
  final Config config;
  final Map<String, dynamic> _loadedPlugins = {};

  PluginManager(this.config);

  int get loadedCount => _loadedPlugins.length;

  Future<void> loadAll() async {
    print('Loading plugins...');

    final enabledPlugins = config.plugins['enabled'] as List? ?? [];

    for (final pluginName in enabledPlugins) {
      await _loadPlugin(pluginName);
    }

    print('✓ Loaded ${_loadedPlugins.length} plugins');
  }

  Future<void> unloadAll() async {
    print('Unloading plugins...');
    _loadedPlugins.clear();
  }

  Future<void> reload(Config newConfig) async {
    await unloadAll();
    await loadAll();
  }

  Future<void> _loadPlugin(String pluginName) async {
    // TODO: Implement dynamic plugin loading
    print('  Loading plugin: $pluginName');
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
