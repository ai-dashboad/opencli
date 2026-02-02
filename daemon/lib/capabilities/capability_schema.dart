import 'package:yaml/yaml.dart';

/// Capability package metadata and workflow definition
///
/// Example capability package (YAML):
/// ```yaml
/// id: desktop.open_app
/// version: 1.2.3
/// name: Open Application
/// description: Opens an application by name
/// author: opencli
/// min_executor_version: 0.1.0
/// platforms: [macos, windows, linux]
///
/// # Input parameters
/// parameters:
///   - name: app_name
///     type: string
///     required: true
///     description: Name of the application to open
///
/// # Execution workflow
/// workflow:
///   - action: find_app
///     params:
///       name: "${app_name}"
///   - action: launch_process
///     params:
///       path: "${found_path}"
///   - action: wait_window
///     timeout: 5s
///
/// # Required base executors
/// requires_executors:
///   - process_launcher
///   - window_detector
/// ```

/// Supported platforms
enum CapabilityPlatform {
  macos,
  windows,
  linux,
  all,
}

/// Parameter types for capability inputs
enum ParameterType {
  string,
  int,
  double,
  bool,
  list,
  map,
  file,
  directory,
}

/// Capability parameter definition
class CapabilityParameter {
  final String name;
  final ParameterType type;
  final bool required;
  final String? description;
  final dynamic defaultValue;
  final List<String>? allowedValues;

  const CapabilityParameter({
    required this.name,
    required this.type,
    this.required = false,
    this.description,
    this.defaultValue,
    this.allowedValues,
  });

  factory CapabilityParameter.fromYaml(YamlMap yaml) {
    return CapabilityParameter(
      name: yaml['name'] as String,
      type: _parseType(yaml['type'] as String?),
      required: yaml['required'] as bool? ?? false,
      description: yaml['description'] as String?,
      defaultValue: yaml['default'],
      allowedValues: (yaml['allowed_values'] as YamlList?)?.cast<String>(),
    );
  }

  static ParameterType _parseType(String? type) {
    switch (type) {
      case 'string':
        return ParameterType.string;
      case 'int':
      case 'integer':
        return ParameterType.int;
      case 'double':
      case 'float':
      case 'number':
        return ParameterType.double;
      case 'bool':
      case 'boolean':
        return ParameterType.bool;
      case 'list':
      case 'array':
        return ParameterType.list;
      case 'map':
      case 'object':
        return ParameterType.map;
      case 'file':
        return ParameterType.file;
      case 'directory':
      case 'dir':
        return ParameterType.directory;
      default:
        return ParameterType.string;
    }
  }

  /// Validate a value against this parameter definition
  bool validate(dynamic value) {
    if (value == null) {
      return !required;
    }

    switch (type) {
      case ParameterType.string:
        if (value is! String) return false;
        if (allowedValues != null && !allowedValues!.contains(value)) return false;
        return true;
      case ParameterType.int:
        return value is int;
      case ParameterType.double:
        return value is num;
      case ParameterType.bool:
        return value is bool;
      case ParameterType.list:
        return value is List;
      case ParameterType.map:
        return value is Map;
      case ParameterType.file:
      case ParameterType.directory:
        return value is String;
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'required': required,
    'description': description,
    'defaultValue': defaultValue,
    'allowedValues': allowedValues,
  };
}

/// Workflow action step
class WorkflowAction {
  final String action;
  final Map<String, dynamic> params;
  final String? onError;
  final Duration? timeout;
  final String? condition;
  final String? storeResult;

  const WorkflowAction({
    required this.action,
    this.params = const {},
    this.onError,
    this.timeout,
    this.condition,
    this.storeResult,
  });

  factory WorkflowAction.fromYaml(YamlMap yaml) {
    return WorkflowAction(
      action: yaml['action'] as String,
      params: _parseParams(yaml['params']),
      onError: yaml['on_error'] as String?,
      timeout: _parseDuration(yaml['timeout'] as String?),
      condition: yaml['condition'] as String?,
      storeResult: yaml['store_result'] as String?,
    );
  }

  static Map<String, dynamic> _parseParams(dynamic params) {
    if (params == null) return {};
    if (params is YamlMap) {
      return Map<String, dynamic>.from(params);
    }
    return {};
  }

  static Duration? _parseDuration(String? value) {
    if (value == null) return null;

    final match = RegExp(r'^(\d+)(s|ms|m|h)?$').firstMatch(value);
    if (match == null) return null;

    final amount = int.parse(match.group(1)!);
    final unit = match.group(2) ?? 's';

    switch (unit) {
      case 'ms':
        return Duration(milliseconds: amount);
      case 's':
        return Duration(seconds: amount);
      case 'm':
        return Duration(minutes: amount);
      case 'h':
        return Duration(hours: amount);
      default:
        return Duration(seconds: amount);
    }
  }

  Map<String, dynamic> toJson() => {
    'action': action,
    'params': params,
    'onError': onError,
    'timeout': timeout?.inMilliseconds,
    'condition': condition,
    'storeResult': storeResult,
  };
}

/// Capability package definition
class CapabilityPackage {
  /// Unique identifier (e.g., 'desktop.open_app')
  final String id;

  /// Semantic version (e.g., '1.2.3')
  final String version;

  /// Human-readable name
  final String name;

  /// Package description
  final String? description;

  /// Package author
  final String? author;

  /// Minimum executor version required
  final String minExecutorVersion;

  /// Supported platforms
  final List<CapabilityPlatform> platforms;

  /// Input parameters
  final List<CapabilityParameter> parameters;

  /// Workflow steps
  final List<WorkflowAction> workflow;

  /// Required base executors
  final List<String> requiresExecutors;

  /// Package tags for discovery
  final List<String> tags;

  /// Whether this is a system capability
  final bool isSystem;

  /// Package checksum for verification
  final String? checksum;

  /// Last updated timestamp
  final DateTime? updatedAt;

  const CapabilityPackage({
    required this.id,
    required this.version,
    required this.name,
    this.description,
    this.author,
    this.minExecutorVersion = '0.1.0',
    this.platforms = const [CapabilityPlatform.all],
    this.parameters = const [],
    this.workflow = const [],
    this.requiresExecutors = const [],
    this.tags = const [],
    this.isSystem = false,
    this.checksum,
    this.updatedAt,
  });

  /// Parse from YAML string
  factory CapabilityPackage.fromYamlString(String yaml) {
    final doc = loadYaml(yaml) as YamlMap;
    return CapabilityPackage.fromYaml(doc);
  }

  /// Parse from YAML map
  factory CapabilityPackage.fromYaml(YamlMap yaml) {
    return CapabilityPackage(
      id: yaml['id'] as String,
      version: yaml['version'] as String? ?? '1.0.0',
      name: yaml['name'] as String? ?? yaml['id'] as String,
      description: yaml['description'] as String?,
      author: yaml['author'] as String?,
      minExecutorVersion: yaml['min_executor_version'] as String? ?? '0.1.0',
      platforms: _parsePlatforms(yaml['platforms']),
      parameters: _parseParameters(yaml['parameters']),
      workflow: _parseWorkflow(yaml['workflow']),
      requiresExecutors: (yaml['requires_executors'] as YamlList?)
          ?.cast<String>()
          .toList() ?? [],
      tags: (yaml['tags'] as YamlList?)?.cast<String>().toList() ?? [],
      isSystem: yaml['is_system'] as bool? ?? false,
      checksum: yaml['checksum'] as String?,
      updatedAt: yaml['updated_at'] != null
          ? DateTime.tryParse(yaml['updated_at'] as String)
          : null,
    );
  }

  static List<CapabilityPlatform> _parsePlatforms(dynamic platforms) {
    if (platforms == null) return [CapabilityPlatform.all];

    final list = (platforms as YamlList).cast<String>();
    return list.map((p) {
      switch (p.toLowerCase()) {
        case 'macos':
        case 'darwin':
          return CapabilityPlatform.macos;
        case 'windows':
        case 'win':
        case 'win32':
          return CapabilityPlatform.windows;
        case 'linux':
          return CapabilityPlatform.linux;
        default:
          return CapabilityPlatform.all;
      }
    }).toList();
  }

  static List<CapabilityParameter> _parseParameters(dynamic params) {
    if (params == null) return [];
    return (params as YamlList)
        .cast<YamlMap>()
        .map((p) => CapabilityParameter.fromYaml(p))
        .toList();
  }

  static List<WorkflowAction> _parseWorkflow(dynamic workflow) {
    if (workflow == null) return [];
    return (workflow as YamlList)
        .cast<YamlMap>()
        .map((w) => WorkflowAction.fromYaml(w))
        .toList();
  }

  /// Check if capability supports current platform
  bool supportsPlatform(String platform) {
    if (platforms.contains(CapabilityPlatform.all)) return true;

    final current = switch (platform.toLowerCase()) {
      'macos' => CapabilityPlatform.macos,
      'windows' => CapabilityPlatform.windows,
      'linux' => CapabilityPlatform.linux,
      _ => CapabilityPlatform.all,
    };

    return platforms.contains(current);
  }

  /// Validate input parameters
  List<String> validateParameters(Map<String, dynamic> input) {
    final errors = <String>[];

    for (final param in parameters) {
      final value = input[param.name] ?? param.defaultValue;

      if (param.required && value == null) {
        errors.add('Missing required parameter: ${param.name}');
        continue;
      }

      if (value != null && !param.validate(value)) {
        errors.add('Invalid value for parameter ${param.name}: $value');
      }
    }

    return errors;
  }

  /// Compare versions
  int compareVersion(String other) {
    final thisParts = version.split('.').map(int.tryParse).toList();
    final otherParts = other.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final a = i < thisParts.length ? (thisParts[i] ?? 0) : 0;
      final b = i < otherParts.length ? (otherParts[i] ?? 0) : 0;

      if (a > b) return 1;
      if (a < b) return -1;
    }

    return 0;
  }

  /// Check if this version is newer than another
  bool isNewerThan(String other) => compareVersion(other) > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'name': name,
    'description': description,
    'author': author,
    'minExecutorVersion': minExecutorVersion,
    'platforms': platforms.map((p) => p.name).toList(),
    'parameters': parameters.map((p) => p.toJson()).toList(),
    'workflow': workflow.map((w) => w.toJson()).toList(),
    'requiresExecutors': requiresExecutors,
    'tags': tags,
    'isSystem': isSystem,
    'checksum': checksum,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  @override
  String toString() => 'CapabilityPackage($id@$version)';
}

/// Capability package manifest for a repository
class CapabilityManifest {
  final String repositoryUrl;
  final String repositoryVersion;
  final List<CapabilityPackageInfo> packages;
  final DateTime updatedAt;

  const CapabilityManifest({
    required this.repositoryUrl,
    required this.repositoryVersion,
    required this.packages,
    required this.updatedAt,
  });

  factory CapabilityManifest.fromJson(Map<String, dynamic> json) {
    return CapabilityManifest(
      repositoryUrl: json['repository_url'] as String,
      repositoryVersion: json['repository_version'] as String? ?? '1.0.0',
      packages: (json['packages'] as List<dynamic>)
          .map((p) => CapabilityPackageInfo.fromJson(p as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'repository_url': repositoryUrl,
    'repository_version': repositoryVersion,
    'packages': packages.map((p) => p.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Summary info about a capability package
class CapabilityPackageInfo {
  final String id;
  final String version;
  final String name;
  final String? description;
  final List<String> platforms;
  final String downloadUrl;
  final String? checksum;
  final int? size;

  const CapabilityPackageInfo({
    required this.id,
    required this.version,
    required this.name,
    this.description,
    required this.platforms,
    required this.downloadUrl,
    this.checksum,
    this.size,
  });

  factory CapabilityPackageInfo.fromJson(Map<String, dynamic> json) {
    return CapabilityPackageInfo(
      id: json['id'] as String,
      version: json['version'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      platforms: (json['platforms'] as List<dynamic>).cast<String>(),
      downloadUrl: json['download_url'] as String,
      checksum: json['checksum'] as String?,
      size: json['size'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'name': name,
    'description': description,
    'platforms': platforms,
    'download_url': downloadUrl,
    'checksum': checksum,
    'size': size,
  };
}
