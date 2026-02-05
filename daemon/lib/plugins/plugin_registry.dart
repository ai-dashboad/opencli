/// Plugin Registry
///
/// Manages installed plugins and their capabilities.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'plugin_sdk.dart';

/// Plugin Registry - Central registry for all installed plugins
class PluginRegistry {
  final String pluginsDirectory;
  final Map<String, PluginMetadata> _installedPlugins = {};
  final Map<String, OpenCLIPlugin> _loadedPlugins = {};
  final Map<String, List<String>> _capabilityIndex = {}; // capability -> plugin IDs

  PluginRegistry({required this.pluginsDirectory});

  /// Initialize registry and scan for installed plugins
  Future<void> initialize() async {
    await _scanPlugins();
    await _buildCapabilityIndex();
  }

  /// Scan plugins directory for installed plugins
  Future<void> _scanPlugins() async {
    final pluginsDir = Directory(pluginsDirectory);
    if (!await pluginsDir.exists()) {
      await pluginsDir.create(recursive: true);
      return;
    }

    await for (final entity in pluginsDir.list()) {
      if (entity is Directory) {
        await _loadPluginMetadata(entity.path);
      }
    }
  }

  /// Load plugin metadata from plugin.yaml
  Future<void> _loadPluginMetadata(String pluginPath) async {
    try {
      final manifestFile = File(path.join(pluginPath, 'plugin.yaml'));
      if (!await manifestFile.exists()) {
        return;
      }

      final content = await manifestFile.readAsString();
      // TODO: Use yaml package to parse
      final Map<String, dynamic> yaml = {}; // Placeholder
      final metadata = PluginMetadata.fromYaml(yaml);
      _installedPlugins[metadata.id] = metadata;
    } catch (e) {
      print('Error loading plugin metadata from $pluginPath: $e');
    }
  }

  /// Build capability index for fast lookup
  Future<void> _buildCapabilityIndex() async {
    _capabilityIndex.clear();
    for (final metadata in _installedPlugins.values) {
      for (final capability in metadata.capabilities) {
        _capabilityIndex.putIfAbsent(capability.id, () => []).add(metadata.id);
      }
    }
  }

  /// Find plugins that provide a specific capability
  List<PluginMetadata> findPluginsByCapability(String capabilityId) {
    final pluginIds = _capabilityIndex[capabilityId] ?? [];
    return pluginIds
        .map((id) => _installedPlugins[id])
        .whereType<PluginMetadata>()
        .toList();
  }

  /// Get all installed plugins
  List<PluginMetadata> get installedPlugins =>
      _installedPlugins.values.toList();

  /// Get loaded plugin instance
  OpenCLIPlugin? getLoadedPlugin(String pluginId) => _loadedPlugins[pluginId];

  /// Check if plugin is installed
  bool isInstalled(String pluginId) => _installedPlugins.containsKey(pluginId);

  /// Check if plugin is loaded
  bool isLoaded(String pluginId) => _loadedPlugins.containsKey(pluginId);

  /// Get plugin metadata
  PluginMetadata? getMetadata(String pluginId) => _installedPlugins[pluginId];

  /// Register a loaded plugin
  void registerLoadedPlugin(String pluginId, OpenCLIPlugin plugin) {
    _loadedPlugins[pluginId] = plugin;
  }

  /// Unregister a loaded plugin
  void unregisterLoadedPlugin(String pluginId) {
    _loadedPlugins.remove(pluginId);
  }

  /// Get all capabilities across all plugins
  Map<String, List<String>> get capabilityIndex => Map.from(_capabilityIndex);

  /// Search plugins by query
  List<PluginMetadata> search({
    String? query,
    List<String>? tags,
    List<String>? capabilities,
  }) {
    var results = installedPlugins;

    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      results = results.where((p) {
        return p.name.toLowerCase().contains(lowerQuery) ||
            p.description.toLowerCase().contains(lowerQuery) ||
            p.id.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    if (tags != null && tags.isNotEmpty) {
      results = results.where((p) {
        return tags.any((tag) => p.tags.contains(tag));
      }).toList();
    }

    if (capabilities != null && capabilities.isNotEmpty) {
      results = results.where((p) {
        return capabilities.any((cap) =>
            p.capabilities.any((c) => c.id.contains(cap)));
      }).toList();
    }

    return results;
  }

  /// Get plugin statistics
  Map<String, dynamic> getStatistics() {
    return {
      'total_installed': _installedPlugins.length,
      'total_loaded': _loadedPlugins.length,
      'total_capabilities': _capabilityIndex.length,
      'plugins_by_tag': _groupPluginsByTag(),
    };
  }

  Map<String, int> _groupPluginsByTag() {
    final tagCount = <String, int>{};
    for (final plugin in _installedPlugins.values) {
      for (final tag in plugin.tags) {
        tagCount[tag] = (tagCount[tag] ?? 0) + 1;
      }
    }
    return tagCount;
  }
}

/// Capability Matcher - AI-driven capability matching
class CapabilityMatcher {
  final PluginRegistry registry;

  CapabilityMatcher(this.registry);

  /// Extract capabilities from user task description
  Future<List<String>> extractCapabilities(String taskDescription) async {
    // TODO: Implement AI-based capability extraction
    // For now, use simple keyword matching
    final capabilities = <String>[];

    final keywords = {
      'twitter': ['twitter.post', 'twitter.monitor'],
      'tweet': ['twitter.post'],
      'slack': ['slack.post_message'],
      'github': ['github.create_release', 'github.create_pr'],
      'docker': ['docker.build', 'docker.run'],
      'test': ['web.test', 'api.test'],
    };

    final lowerTask = taskDescription.toLowerCase();
    for (final entry in keywords.entries) {
      if (lowerTask.contains(entry.key)) {
        capabilities.addAll(entry.value);
      }
    }

    return capabilities;
  }

  /// Find best plugin for a capability
  PluginMetadata? findBestPlugin(String capability) {
    final candidates = registry.findPluginsByCapability(capability);
    if (candidates.isEmpty) return null;

    // For now, return first match
    // TODO: Implement ranking based on:
    // - Rating
    // - Downloads
    // - Compatibility
    // - Performance
    return candidates.first;
  }

  /// Recommend plugins for a task
  Future<List<PluginRecommendation>> recommendPlugins(
    String taskDescription,
  ) async {
    final capabilities = await extractCapabilities(taskDescription);
    final recommendations = <PluginRecommendation>[];

    for (final capability in capabilities) {
      final plugin = findBestPlugin(capability);
      if (plugin != null) {
        recommendations.add(PluginRecommendation(
          pluginId: plugin.id,
          capability: capability,
          confidence: 0.9, // TODO: Calculate actual confidence
          reason: 'Best match for $capability',
        ));
      } else {
        recommendations.add(PluginRecommendation(
          pluginId: null,
          capability: capability,
          confidence: 0.0,
          reason: 'No plugin found for $capability',
          needsInstall: true,
        ));
      }
    }

    return recommendations;
  }
}

/// Plugin recommendation
class PluginRecommendation {
  final String? pluginId;
  final String capability;
  final double confidence;
  final String reason;
  final bool needsInstall;

  PluginRecommendation({
    this.pluginId,
    required this.capability,
    required this.confidence,
    required this.reason,
    this.needsInstall = false,
  });

  Map<String, dynamic> toJson() => {
        'plugin_id': pluginId,
        'capability': capability,
        'confidence': confidence,
        'reason': reason,
        'needs_install': needsInstall,
      };
}
