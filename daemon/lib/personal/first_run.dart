/// First-run initialization for personal mode
///
/// Handles automatic configuration generation, directory setup,
/// and welcome experience for new users.
library;

import 'dart:io';
import 'dart:convert';

/// First-run manager for personal mode initialization
class FirstRunManager {
  final String configDir;
  final String dataDir;
  final String logsDir;
  final String storageDir;
  final String backupsDir;

  bool _hasRun = false;

  FirstRunManager({
    String? configDir,
    String? dataDir,
    String? logsDir,
    String? storageDir,
    String? backupsDir,
  })  : configDir = configDir ?? _getDefaultConfigDir(),
        dataDir = dataDir ?? _getDefaultDataDir(),
        logsDir = logsDir ?? _getDefaultLogsDir(),
        storageDir = storageDir ?? _getDefaultStorageDir(),
        backupsDir = backupsDir ?? _getDefaultBackupsDir();

  /// Check if this is the first run
  bool isFirstRun() {
    final markerFile = File('$configDir/.initialized');
    return !markerFile.existsSync();
  }

  /// Perform first-run initialization
  Future<FirstRunResult> initialize() async {
    if (_hasRun) {
      return FirstRunResult(
        success: true,
        message: 'Already initialized',
        isFirstRun: false,
      );
    }

    try {
      print('[FirstRun] Starting initialization...');

      // Create directories
      await _createDirectories();

      // Generate default configuration
      await _generateDefaultConfig();

      // Initialize database
      await _initializeDatabase();

      // Create welcome message
      final welcomeMsg = _createWelcomeMessage();

      // Mark as initialized
      await _markAsInitialized();

      _hasRun = true;

      print('[FirstRun] Initialization complete');

      return FirstRunResult(
        success: true,
        message: welcomeMsg,
        isFirstRun: true,
        configPath: '$configDir/config.yaml',
      );
    } catch (e) {
      print('[FirstRun] Initialization failed: $e');
      return FirstRunResult(
        success: false,
        message: 'Initialization failed: $e',
        isFirstRun: true,
      );
    }
  }

  /// Create required directories
  Future<void> _createDirectories() async {
    final dirs = [
      configDir,
      dataDir,
      logsDir,
      storageDir,
      backupsDir,
    ];

    for (var dir in dirs) {
      final directory = Directory(dir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        print('[FirstRun] Created directory: $dir');
      }
    }
  }

  /// Generate default configuration file
  Future<void> _generateDefaultConfig() async {
    final configFile = File('$configDir/config.yaml');

    if (await configFile.exists()) {
      print('[FirstRun] Configuration already exists, skipping');
      return;
    }

    final config = _getDefaultConfig();
    await configFile.writeAsString(config);

    print('[FirstRun] Generated default configuration');
  }

  /// Initialize database
  Future<void> _initializeDatabase() async {
    final dbFile = File('$dataDir/opencli.db');

    if (await dbFile.exists()) {
      print('[FirstRun] Database already exists, skipping');
      return;
    }

    // Create empty database file (actual initialization done by database module)
    await dbFile.create();

    print('[FirstRun] Created database file');
  }

  /// Mark as initialized
  Future<void> _markAsInitialized() async {
    final markerFile = File('$configDir/.initialized');
    final timestamp = DateTime.now().toIso8601String();

    await markerFile.writeAsString(jsonEncode({
      'initialized_at': timestamp,
      'version': '1.0.0',
      'mode': 'personal',
    }));
  }

  /// Get default configuration content
  String _getDefaultConfig() {
    return '''
# OpenCLI Personal Mode - Auto-generated Configuration
# 此配置自动生成，个人用户无需修改即可使用

mode: personal

daemon:
  name: "OpenCLI Personal"
  auto_start: true
  system_tray: true
  log_level: info

database:
  type: sqlite
  path: $dataDir/opencli.db
  auto_backup: true
  backup_interval: daily
  backup_retention: 7

storage:
  type: local
  base_path: $storageDir
  max_file_size: 100MB
  auto_cleanup: true
  cleanup_days: 30

mobile:
  enabled: true
  port: 8765
  auto_discovery: true
  discovery_name: "\${HOSTNAME}-OpenCLI"

  security:
    pairing_required: true
    pairing_timeout: 300
    auto_trust_local: true
    max_devices: 5

  websocket:
    heartbeat_interval: 30
    reconnect_interval: 5
    max_reconnect: 10

automation:
  desktop:
    enabled: true
    screenshot: true
    screen_recording: false
    keyboard_input: true
    mouse_input: true

  files:
    enabled: true
    allowed_paths:
      - ~/Desktop
      - ~/Documents
      - ~/Downloads
    restricted_paths:
      - ~/.ssh

browser:
  enabled: false
  driver: auto
  headless: false

ai:
  enabled: false
  # Uncomment to enable AI features:
  # providers:
  #   - name: local
  #     type: ollama
  #     model: llama2

notifications:
  desktop:
    enabled: true
    level: info
  mobile:
    enabled: true
    push_notifications: false

scheduler:
  enabled: false

backup:
  enabled: true
  auto_backup: true
  schedule: "0 2 * * *"
  retention_days: 7
  compression: true

logging:
  level: info
  console: false
  file: true
  file_path: $logsDir/opencli.log
  rotation: daily
  max_size: 10MB
  retention: 7

monitoring:
  enabled: false
  metrics: false

security:
  authentication:
    type: simple
    session_timeout: 24h

  access_control:
    require_confirmation:
      - delete_file
      - install_app
      - system_command

  audit_log:
    enabled: true
    retention_days: 30

performance:
  max_concurrent_tasks: 5
  task_timeout: 300
  memory_limit: 500MB

network:
  prefer_local: true
  cloud_bridge:
    enabled: false

ui:
  language: auto
  theme: auto

  tray:
    enabled: true
    start_minimized: false
    close_to_tray: true

  shortcuts:
    show_window: "Ctrl+Shift+O"
    screenshot: "Ctrl+Shift+S"
    voice_command: "Ctrl+Shift+V"

updates:
  auto_check: true
  auto_download: true
  auto_install: false
  channel: stable

privacy:
  analytics: false
  crash_reports: true
  usage_stats: false

experimental:
  enabled: false

plugins:
  enabled: false
  auto_load: false

# Advanced settings
ipc:
  socket_path: $configDir/opencli.sock
  timeout: 30

cache:
  enabled: true
  type: memory
  max_size: 100MB
  ttl: 3600

message_queue:
  enabled: false
  type: memory
''';
  }

  /// Create welcome message
  String _createWelcomeMessage() {
    return '''
╔════════════════════════════════════════════════════════════════╗
║                   Welcome to OpenCLI! 🎉                      ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  ✓ Configuration generated                                     ║
║  ✓ Directories created                                         ║
║  ✓ Database initialized                                        ║
║  ✓ Personal mode enabled                                       ║
║                                                                ║
║  Your OpenCLI installation is ready!                           ║
║                                                                ║
║  Next steps:                                                   ║
║  1. Start daemon:    opencli daemon start                      ║
║  2. Check status:    opencli status                            ║
║  3. Pair mobile:     opencli mobile pairing-code               ║
║  4. View help:       opencli help                              ║
║                                                                ║
║  Configuration file: $configDir/config.yaml
║  Data directory:     $dataDir
║  Logs directory:     $logsDir
║                                                                ║
║  For help and documentation:                                   ║
║  https://docs.opencli.dev                                      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
''';
  }

  /// Get default config directory
  static String _getDefaultConfigDir() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    return '$home/.opencli';
  }

  /// Get default data directory
  static String _getDefaultDataDir() {
    return '${_getDefaultConfigDir()}/data';
  }

  /// Get default logs directory
  static String _getDefaultLogsDir() {
    return '${_getDefaultConfigDir()}/logs';
  }

  /// Get default storage directory
  static String _getDefaultStorageDir() {
    return '${_getDefaultConfigDir()}/storage';
  }

  /// Get default backups directory
  static String _getDefaultBackupsDir() {
    return '${_getDefaultConfigDir()}/backups';
  }

  /// Reset first-run state (for testing)
  Future<void> reset() async {
    final markerFile = File('$configDir/.initialized');
    if (await markerFile.exists()) {
      await markerFile.delete();
    }
    _hasRun = false;
  }
}

/// First-run initialization result
class FirstRunResult {
  final bool success;
  final String message;
  final bool isFirstRun;
  final String? configPath;

  FirstRunResult({
    required this.success,
    required this.message,
    required this.isFirstRun,
    this.configPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'is_first_run': isFirstRun,
      'config_path': configPath,
    };
  }
}
