/// Plugin Loader
///
/// Loads and manages plugin lifecycle.
library;

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'plugin_sdk.dart';
import 'plugin_registry.dart';

/// Plugin Loader - Manages plugin loading and execution
class PluginLoader {
  final PluginRegistry registry;
  final SecurityManager securityManager;

  PluginLoader({
    required this.registry,
    required this.securityManager,
  });

  /// Load a plugin by ID
  Future<OpenCLIPlugin> loadPlugin(String pluginId) async {
    // Check if already loaded
    final loaded = registry.getLoadedPlugin(pluginId);
    if (loaded != null) return loaded;

    // Get metadata
    final metadata = registry.getMetadata(pluginId);
    if (metadata == null) {
      throw PluginLoadException('Plugin not installed: $pluginId');
    }

    // Check permissions
    await securityManager.checkPermissions(metadata.permissions);

    // Load dependencies first
    for (final dep in metadata.dependencies) {
      await loadPlugin(dep.id);
    }

    // Load plugin (simplified - in reality would use isolates/dynamic loading)
    final plugin = await _instantiatePlugin(pluginId, metadata);

    // Initialize plugin
    await plugin.initialize();

    // Validate configuration
    if (!await plugin.validate()) {
      throw PluginConfigurationException(
        'Plugin validation failed: $pluginId',
      );
    }

    // Register loaded plugin
    registry.registerLoadedPlugin(pluginId, plugin);

    return plugin;
  }

  /// Unload a plugin
  Future<void> unloadPlugin(String pluginId) async {
    final plugin = registry.getLoadedPlugin(pluginId);
    if (plugin == null) return;

    await plugin.dispose();
    registry.unregisterLoadedPlugin(pluginId);
  }

  /// Execute plugin capability
  Future<PluginResult> execute(
    String pluginId,
    String capability,
    Map<String, dynamic> params,
  ) async {
    // Load plugin if not loaded
    final plugin = await loadPlugin(pluginId);

    // Execute capability
    try {
      return await plugin.execute(capability, params);
    } catch (e) {
      return PluginResult.failure(
        message: 'Plugin execution failed: $e',
        error: PluginError(
          code: 'EXECUTION_ERROR',
          message: e.toString(),
          stackTrace: e is Error ? e.stackTrace.toString() : null,
        ),
      );
    }
  }

  /// Instantiate plugin (placeholder - would use dynamic loading in production)
  Future<OpenCLIPlugin> _instantiatePlugin(
    String pluginId,
    PluginMetadata metadata,
  ) async {
    // TODO: Implement dynamic plugin loading using dart:isolate or dart:mirrors
    // For now, throw exception
    throw PluginLoadException(
      'Dynamic plugin loading not yet implemented for: $pluginId',
    );
  }

  /// Reload all plugins
  Future<void> reloadAll() async {
    final loadedIds = registry._loadedPlugins.keys.toList();
    for (final id in loadedIds) {
      await unloadPlugin(id);
      await loadPlugin(id);
    }
  }
}

/// Security Manager - Manages plugin permissions and security
class SecurityManager {
  final Map<String, bool> _grantedPermissions = {};

  /// Check if permissions are granted
  Future<void> checkPermissions(List<String> permissions) async {
    for (final permission in permissions) {
      if (!await hasPermission(permission)) {
        throw PermissionDeniedException(permission);
      }
    }
  }

  /// Check if specific permission is granted
  Future<bool> hasPermission(String permission) async {
    // Check cache
    if (_grantedPermissions.containsKey(permission)) {
      return _grantedPermissions[permission]!;
    }

    // Ask user for permission (simplified)
    final granted = await _requestPermission(permission);
    _grantedPermissions[permission] = granted;
    return granted;
  }

  /// Request permission from user
  Future<bool> _requestPermission(String permission) async {
    // TODO: Implement UI for permission requests
    // For now, auto-grant for development
    print('⚠️  Plugin requesting permission: $permission');
    return true;
  }

  /// Grant permission
  void grantPermission(String permission) {
    _grantedPermissions[permission] = true;
  }

  /// Revoke permission
  void revokePermission(String permission) {
    _grantedPermissions[permission] = false;
  }

  /// Clear all permissions
  void clearPermissions() {
    _grantedPermissions.clear();
  }
}

/// Plugin Executor - High-level plugin execution interface
class PluginExecutor {
  final PluginLoader loader;
  final PluginRegistry registry;
  final CapabilityMatcher matcher;

  PluginExecutor({
    required this.loader,
    required this.registry,
    required this.matcher,
  });

  /// Execute task using natural language
  Future<PluginResult> executeTask(String taskDescription) async {
    // Get recommendations
    final recommendations = await matcher.recommendPlugins(taskDescription);

    if (recommendations.isEmpty) {
      return PluginResult.failure(
        message: 'No plugins found for task: $taskDescription',
      );
    }

    // Find first plugin that doesn't need install
    final availableRec = recommendations.firstWhere(
      (r) => !r.needsInstall && r.pluginId != null,
      orElse: () => recommendations.first,
    );

    if (availableRec.needsInstall) {
      return PluginResult.failure(
        message: 'Required plugin not installed: ${availableRec.capability}',
        data: {
          'capability': availableRec.capability,
          'recommendation': availableRec.toJson(),
        },
      );
    }

    // Execute capability
    return await loader.execute(
      availableRec.pluginId!,
      availableRec.capability,
      _extractParams(taskDescription),
    );
  }

  /// Execute specific capability
  Future<PluginResult> executeCapability(
    String capability,
    Map<String, dynamic> params,
  ) async {
    final plugin = matcher.findBestPlugin(capability);
    if (plugin == null) {
      return PluginResult.failure(
        message: 'No plugin found for capability: $capability',
      );
    }

    return await loader.execute(plugin.id, capability, params);
  }

  /// Extract parameters from task description (simplified)
  Map<String, dynamic> _extractParams(String taskDescription) {
    // TODO: Implement AI-based parameter extraction
    return {'task_description': taskDescription};
  }
}
