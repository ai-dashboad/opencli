import 'dart:async';
import 'dart:io';
import 'capability_schema.dart';
import 'capability_loader.dart';

/// Registry of available capabilities
class CapabilityRegistry {
  final CapabilityLoader _loader;

  /// Registered capabilities
  final Map<String, CapabilityPackage> _capabilities = {};

  /// Capability aliases (e.g., 'open_app' -> 'desktop.open_app')
  final Map<String, String> _aliases = {};

  /// Listeners for capability changes
  final List<void Function(String id, CapabilityPackage?)> _listeners = [];

  /// Current platform
  final String currentPlatform;

  CapabilityRegistry({
    required CapabilityLoader loader,
    String? platform,
  }) : _loader = loader,
       currentPlatform = platform ?? Platform.operatingSystem;

  /// Initialize registry
  Future<void> initialize() async {
    await _loader.initialize();
    await _loadBuiltinCapabilities();
  }

  /// Load built-in capabilities
  Future<void> _loadBuiltinCapabilities() async {
    // Register built-in capabilities
    final builtins = _getBuiltinCapabilities();
    for (final capability in builtins) {
      register(capability);
    }

    print('[CapabilityRegistry] Registered ${builtins.length} built-in capabilities');
  }

  /// Get built-in capability definitions
  List<CapabilityPackage> _getBuiltinCapabilities() {
    return [
      // Open Application
      CapabilityPackage(
        id: 'desktop.open_app',
        version: '1.0.0',
        name: 'Open Application',
        description: 'Opens an application by name',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [
          CapabilityParameter(
            name: 'app_name',
            type: ParameterType.string,
            required: true,
            description: 'Name of the application to open',
          ),
        ],
        workflow: [
          WorkflowAction(
            action: 'open_app',
            params: {'app_name': r'${app_name}'},
          ),
        ],
        requiresExecutors: ['open_app'],
        tags: ['desktop', 'app', 'launch'],
        isSystem: true,
      ),

      // Close Application
      CapabilityPackage(
        id: 'desktop.close_app',
        version: '1.0.0',
        name: 'Close Application',
        description: 'Closes an application by name',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [
          CapabilityParameter(
            name: 'app_name',
            type: ParameterType.string,
            required: true,
            description: 'Name of the application to close',
          ),
        ],
        workflow: [
          WorkflowAction(
            action: 'close_app',
            params: {'app_name': r'${app_name}'},
          ),
        ],
        requiresExecutors: ['close_app'],
        tags: ['desktop', 'app', 'close'],
        isSystem: true,
      ),

      // Screenshot
      CapabilityPackage(
        id: 'desktop.screenshot',
        version: '1.0.0',
        name: 'Take Screenshot',
        description: 'Captures a screenshot of the screen',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [
          CapabilityParameter(
            name: 'output_path',
            type: ParameterType.string,
            required: false,
            description: 'Path to save the screenshot',
          ),
        ],
        workflow: [
          WorkflowAction(
            action: 'screenshot',
            params: {'output_path': r'${output_path}'},
          ),
        ],
        requiresExecutors: ['screenshot'],
        tags: ['desktop', 'screenshot', 'capture'],
        isSystem: true,
      ),

      // Open URL
      CapabilityPackage(
        id: 'web.open_url',
        version: '1.0.0',
        name: 'Open URL',
        description: 'Opens a URL in the default browser',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [
          CapabilityParameter(
            name: 'url',
            type: ParameterType.string,
            required: true,
            description: 'URL to open',
          ),
        ],
        workflow: [
          WorkflowAction(
            action: 'open_url',
            params: {'url': r'${url}'},
          ),
        ],
        requiresExecutors: ['open_url'],
        tags: ['web', 'browser', 'url'],
        isSystem: true,
      ),

      // Web Search
      CapabilityPackage(
        id: 'web.search',
        version: '1.0.0',
        name: 'Web Search',
        description: 'Performs a web search',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [
          CapabilityParameter(
            name: 'query',
            type: ParameterType.string,
            required: true,
            description: 'Search query',
          ),
        ],
        workflow: [
          WorkflowAction(
            action: 'web_search',
            params: {'query': r'${query}'},
          ),
        ],
        requiresExecutors: ['web_search'],
        tags: ['web', 'search', 'google'],
        isSystem: true,
      ),

      // System Info
      CapabilityPackage(
        id: 'system.info',
        version: '1.0.0',
        name: 'System Information',
        description: 'Gets system information',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [],
        workflow: [
          WorkflowAction(action: 'system_info', params: {}),
        ],
        requiresExecutors: ['system_info'],
        tags: ['system', 'info'],
        isSystem: true,
      ),

      // File Operations
      CapabilityPackage(
        id: 'file.list',
        version: '1.0.0',
        name: 'List Files',
        description: 'Lists files in a directory',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [
          CapabilityParameter(
            name: 'directory',
            type: ParameterType.directory,
            required: false,
            description: 'Directory to list',
            defaultValue: '~',
          ),
        ],
        workflow: [
          WorkflowAction(
            action: 'file_operation',
            params: {
              'operation': 'list',
              'directory': r'${directory}',
            },
          ),
        ],
        requiresExecutors: ['file_operation'],
        tags: ['file', 'list', 'directory'],
        isSystem: true,
      ),

      // Run Command
      CapabilityPackage(
        id: 'system.run_command',
        version: '1.0.0',
        name: 'Run Command',
        description: 'Runs a shell command',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [
          CapabilityParameter(
            name: 'command',
            type: ParameterType.string,
            required: true,
            description: 'Command to run',
          ),
          CapabilityParameter(
            name: 'args',
            type: ParameterType.list,
            required: false,
            description: 'Command arguments',
          ),
        ],
        workflow: [
          WorkflowAction(
            action: 'run_command',
            params: {
              'command': r'${command}',
              'args': r'${args}',
            },
            timeout: const Duration(seconds: 120),
          ),
        ],
        requiresExecutors: ['run_command'],
        tags: ['system', 'command', 'shell'],
        isSystem: true,
      ),

      // AI Query
      CapabilityPackage(
        id: 'ai.query',
        version: '1.0.0',
        name: 'AI Query',
        description: 'Query the AI assistant',
        author: 'opencli',
        platforms: [CapabilityPlatform.all],
        parameters: [
          CapabilityParameter(
            name: 'query',
            type: ParameterType.string,
            required: true,
            description: 'Question or request for the AI',
          ),
        ],
        workflow: [
          WorkflowAction(
            action: 'ai_query',
            params: {'query': r'${query}'},
          ),
        ],
        requiresExecutors: ['ai_query'],
        tags: ['ai', 'query', 'assistant'],
        isSystem: true,
      ),
    ];
  }

  /// Register a capability
  void register(CapabilityPackage capability) {
    // Check platform compatibility
    if (!capability.supportsPlatform(currentPlatform)) {
      print('[CapabilityRegistry] Skipping ${capability.id}: not supported on $currentPlatform');
      return;
    }

    // Check if newer version already exists
    final existing = _capabilities[capability.id];
    if (existing != null && existing.compareVersion(capability.version) >= 0) {
      return;
    }

    _capabilities[capability.id] = capability;

    // Register alias (last part of ID)
    final alias = capability.id.split('.').last;
    if (!_aliases.containsKey(alias) || _capabilities[_aliases[alias]]!.isNewerThan(capability.version)) {
      _aliases[alias] = capability.id;
    }

    // Notify listeners
    for (final listener in _listeners) {
      listener(capability.id, capability);
    }
  }

  /// Unregister a capability
  void unregister(String id) {
    final capability = _capabilities.remove(id);
    if (capability != null) {
      // Remove alias if it points to this capability
      _aliases.removeWhere((_, v) => v == id);

      // Notify listeners
      for (final listener in _listeners) {
        listener(id, null);
      }
    }
  }

  /// Get a capability by ID or alias
  Future<CapabilityPackage?> get(String idOrAlias) async {
    // Try direct ID first
    var capability = _capabilities[idOrAlias];
    if (capability != null) return capability;

    // Try alias
    final id = _aliases[idOrAlias];
    if (id != null) {
      capability = _capabilities[id];
      if (capability != null) return capability;
    }

    // Try to load from loader
    capability = await _loader.get(idOrAlias);
    if (capability != null) {
      register(capability);
      return capability;
    }

    // Try alias lookup in loader
    if (id != null) {
      capability = await _loader.get(id);
      if (capability != null) {
        register(capability);
        return capability;
      }
    }

    return null;
  }

  /// Check if a capability exists
  bool has(String idOrAlias) {
    return _capabilities.containsKey(idOrAlias) ||
           _aliases.containsKey(idOrAlias);
  }

  /// Get all registered capabilities
  List<CapabilityPackage> getAll() {
    return _capabilities.values.toList();
  }

  /// Get capabilities by tag
  List<CapabilityPackage> getByTag(String tag) {
    return _capabilities.values
        .where((c) => c.tags.contains(tag))
        .toList();
  }

  /// Search capabilities by name or description
  List<CapabilityPackage> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _capabilities.values.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
             c.id.toLowerCase().contains(lowerQuery) ||
             (c.description?.toLowerCase().contains(lowerQuery) ?? false) ||
             c.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Add change listener
  void addListener(void Function(String id, CapabilityPackage?) listener) {
    _listeners.add(listener);
  }

  /// Remove change listener
  void removeListener(void Function(String id, CapabilityPackage?) listener) {
    _listeners.remove(listener);
  }

  /// Refresh capabilities from remote
  Future<void> refresh() async {
    final manifest = await _loader.getManifest(forceRefresh: true);
    if (manifest == null) return;

    for (final info in manifest.packages) {
      // Check if we have a newer version available
      final existing = _capabilities[info.id];
      if (existing == null || info.version != existing.version) {
        // Load the new package
        final package = await _loader.get(info.id);
        if (package != null) {
          register(package);
        }
      }
    }

    print('[CapabilityRegistry] Refreshed ${manifest.packages.length} packages');
  }

  /// Get registry statistics
  Map<String, dynamic> getStats() {
    final byPlatform = <String, int>{};
    final byCategory = <String, int>{};

    for (final cap in _capabilities.values) {
      for (final platform in cap.platforms) {
        byPlatform[platform.name] = (byPlatform[platform.name] ?? 0) + 1;
      }

      final category = cap.id.split('.').first;
      byCategory[category] = (byCategory[category] ?? 0) + 1;
    }

    return {
      'totalCapabilities': _capabilities.length,
      'aliases': _aliases.length,
      'byPlatform': byPlatform,
      'byCategory': byCategory,
      'loader': _loader.getStats(),
    };
  }
}
