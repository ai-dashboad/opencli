import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

class Config {
  final String configPath;
  final String socketPath;
  final bool autoMode;
  final Map<String, dynamic> models;
  final Map<String, dynamic> cache;
  final Map<String, dynamic> plugins;

  Config({
    required this.configPath,
    required this.socketPath,
    required this.autoMode,
    required this.models,
    required this.cache,
    required this.plugins,
  });

  static Future<Config> load() async {
    final configPath = _getConfigPath();

    // Create default config if not exists
    if (!await File(configPath).exists()) {
      await _createDefaultConfig(configPath);
    }

    final content = await File(configPath).readAsString();
    final yaml = loadYaml(content) as Map;

    return Config(
      configPath: configPath,
      socketPath: yaml['security']?['socket_path'] ?? '/tmp/opencli.sock',
      autoMode: yaml['auto_mode'] ?? true,
      models: Map<String, dynamic>.from(yaml['models'] ?? {}),
      cache: Map<String, dynamic>.from(yaml['cache'] ?? {}),
      plugins: Map<String, dynamic>.from(yaml['plugins'] ?? {}),
    );
  }

  static String _getConfigPath() {
    final home = Platform.environment['HOME'] ?? '.';
    return path.join(home, '.opencli', 'config.yaml');
  }

  static Future<void> _createDefaultConfig(String configPath) async {
    final dir = path.dirname(configPath);
    await Directory(dir).create(recursive: true);

    const defaultConfig = '''
config_version: 1
auto_mode: true

models:
  priority:
    - tinylm
    - ollama
    - claude

cache:
  enabled: true
  l1:
    max_size: 100
  l2:
    max_size: 1000
  l3:
    enabled: true
    max_size_mb: 500

plugins:
  auto_load: true
  enabled: []

security:
  socket_path: /tmp/opencli.sock
  socket_permissions: 0600
''';

    await File(configPath).writeAsString(defaultConfig);
  }
}
