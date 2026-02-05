/// OpenCLI Plugin SDK
///
/// Base classes and utilities for building OpenCLI plugins.
library opencli_plugin_sdk;

import 'dart:async';

/// Base class for all OpenCLI plugins
abstract class OpenCLIPlugin {
  /// Plugin unique identifier (e.g., @opencli/my-plugin)
  String get id;

  /// Plugin version (semantic versioning)
  String get version;

  /// Plugin name
  String get name;

  /// Plugin description
  String get description;

  /// Plugin capabilities
  List<PluginCapability> get capabilities;

  /// Required permissions
  List<String> get permissions;

  /// Plugin configuration
  Map<String, dynamic> get configuration => {};

  /// Execute a plugin capability
  Future<PluginResult> execute(
    String capability,
    Map<String, dynamic> params,
  );

  /// Initialize plugin (called when plugin is loaded)
  Future<void> initialize() async {}

  /// Cleanup plugin resources (called when plugin is unloaded)
  Future<void> dispose() async {}

  /// Validate plugin configuration
  Future<bool> validate() async => true;
}

/// Plugin capability definition
class PluginCapability {
  final String id;
  final String name;
  final String description;
  final List<CapabilityParameter> parameters;

  const PluginCapability({
    required this.id,
    required this.name,
    required this.description,
    this.parameters = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'parameters': parameters.map((p) => p.toJson()).toList(),
      };
}

/// Capability parameter definition
class CapabilityParameter {
  final String name;
  final String type;
  final bool required;
  final String? description;
  final dynamic defaultValue;

  const CapabilityParameter({
    required this.name,
    required this.type,
    this.required = false,
    this.description,
    this.defaultValue,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'required': required,
        'description': description,
        'default_value': defaultValue,
      };
}

/// Plugin execution result
class PluginResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final PluginError? error;

  const PluginResult({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  factory PluginResult.success({
    required String message,
    Map<String, dynamic>? data,
  }) {
    return PluginResult(
      success: true,
      message: message,
      data: data,
    );
  }

  factory PluginResult.failure({
    required String message,
    PluginError? error,
  }) {
    return PluginResult(
      success: false,
      message: message,
      error: error,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        'data': data,
        'error': error?.toJson(),
      };
}

/// Plugin error
class PluginError {
  final String code;
  final String message;
  final String? stackTrace;

  const PluginError({
    required this.code,
    required this.message,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'stack_trace': stackTrace,
      };
}

/// Plugin metadata (from plugin.yaml)
class PluginMetadata {
  final String id;
  final String name;
  final String version;
  final String description;
  final PluginAuthor? author;
  final String license;
  final List<PluginCapability> capabilities;
  final List<String> permissions;
  final List<PluginDependency> dependencies;
  final List<ConfigurationItem> configuration;
  final List<String> tags;
  final List<String> platforms;
  final String minOpenCLIVersion;

  const PluginMetadata({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.author,
    this.license = 'MIT',
    this.capabilities = const [],
    this.permissions = const [],
    this.dependencies = const [],
    this.configuration = const [],
    this.tags = const [],
    this.platforms = const [],
    this.minOpenCLIVersion = '0.1.0',
  });

  factory PluginMetadata.fromYaml(Map<String, dynamic> yaml) {
    return PluginMetadata(
      id: yaml['id'] as String,
      name: yaml['name'] as String,
      version: yaml['version'] as String,
      description: yaml['description'] as String,
      author: yaml['author'] != null
          ? PluginAuthor.fromYaml(yaml['author'])
          : null,
      license: yaml['license'] as String? ?? 'MIT',
      capabilities: (yaml['capabilities'] as List?)
              ?.map((c) => PluginCapability(
                    id: c['id'] as String,
                    name: c['name'] as String,
                    description: c['description'] as String,
                    parameters: (c['params'] as List?)
                            ?.map((p) => CapabilityParameter(
                                  name: p['name'] as String,
                                  type: p['type'] as String,
                                  required: p['required'] as bool? ?? false,
                                  description: p['description'] as String?,
                                ))
                            .toList() ??
                        [],
                  ))
              .toList() ??
          [],
      permissions:
          (yaml['permissions'] as List?)?.map((p) => p as String).toList() ??
              [],
      dependencies: (yaml['dependencies'] as List?)
              ?.map((d) => PluginDependency.fromYaml(d))
              .toList() ??
          [],
      configuration: (yaml['configuration'] as List?)
              ?.map((c) => ConfigurationItem.fromYaml(c))
              .toList() ??
          [],
      tags: (yaml['tags'] as List?)?.map((t) => t as String).toList() ?? [],
      platforms:
          (yaml['platforms'] as List?)?.map((p) => p as String).toList() ?? [],
      minOpenCLIVersion: yaml['min_opencli_version'] as String? ?? '0.1.0',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'author': author?.toJson(),
        'license': license,
        'capabilities': capabilities.map((c) => c.toJson()).toList(),
        'permissions': permissions,
        'dependencies': dependencies.map((d) => d.toJson()).toList(),
        'configuration': configuration.map((c) => c.toJson()).toList(),
        'tags': tags,
        'platforms': platforms,
        'min_opencli_version': minOpenCLIVersion,
      };
}

/// Plugin author information
class PluginAuthor {
  final String name;
  final String? email;
  final String? url;

  const PluginAuthor({
    required this.name,
    this.email,
    this.url,
  });

  factory PluginAuthor.fromYaml(Map<String, dynamic> yaml) {
    return PluginAuthor(
      name: yaml['name'] as String,
      email: yaml['email'] as String?,
      url: yaml['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'url': url,
      };
}

/// Plugin dependency
class PluginDependency {
  final String id;
  final String version;

  const PluginDependency({
    required this.id,
    required this.version,
  });

  factory PluginDependency.fromYaml(Map<String, dynamic> yaml) {
    return PluginDependency(
      id: yaml['id'] as String,
      version: yaml['version'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
      };
}

/// Configuration item
class ConfigurationItem {
  final String key;
  final String type;
  final bool secret;
  final bool required;
  final String? description;
  final dynamic defaultValue;

  const ConfigurationItem({
    required this.key,
    required this.type,
    this.secret = false,
    this.required = false,
    this.description,
    this.defaultValue,
  });

  factory ConfigurationItem.fromYaml(Map<String, dynamic> yaml) {
    return ConfigurationItem(
      key: yaml['key'] as String,
      type: yaml['type'] as String,
      secret: yaml['secret'] as bool? ?? false,
      required: yaml['required'] as bool? ?? false,
      description: yaml['description'] as String?,
      defaultValue: yaml['default_value'],
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type,
        'secret': secret,
        'required': required,
        'description': description,
        'default_value': defaultValue,
      };
}

/// Plugin exceptions
class UnknownCapabilityException implements Exception {
  final String capability;

  UnknownCapabilityException(this.capability);

  @override
  String toString() => 'Unknown capability: $capability';
}

class PluginLoadException implements Exception {
  final String message;

  PluginLoadException(this.message);

  @override
  String toString() => 'Failed to load plugin: $message';
}

class PermissionDeniedException implements Exception {
  final String permission;

  PermissionDeniedException(this.permission);

  @override
  String toString() => 'Permission denied: $permission';
}

class PluginConfigurationException implements Exception {
  final String message;

  PluginConfigurationException(this.message);

  @override
  String toString() => 'Plugin configuration error: $message';
}
