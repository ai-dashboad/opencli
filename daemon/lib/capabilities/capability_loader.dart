import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'capability_schema.dart';

/// Loads and caches capability packages
class CapabilityLoader {
  /// Local cache directory
  final String cacheDirectory;

  /// Remote repository URL
  final String repositoryUrl;

  /// Cache of loaded packages
  final Map<String, CapabilityPackage> _cache = {};

  /// Remote manifest (cached)
  CapabilityManifest? _manifest;

  /// Last manifest fetch time
  DateTime? _lastManifestFetch;

  /// Manifest cache duration
  final Duration manifestCacheDuration;

  CapabilityLoader({
    String? cacheDirectory,
    this.repositoryUrl = 'https://opencli.ai/api/capabilities',
    this.manifestCacheDuration = const Duration(hours: 1),
  }) : cacheDirectory = cacheDirectory ?? _defaultCacheDir();

  static String _defaultCacheDir() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.opencli/capabilities';
  }

  /// Initialize loader and local cache
  Future<void> initialize() async {
    final dir = Directory(cacheDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Load cached packages
    await _loadLocalPackages();
  }

  /// Load all locally cached packages
  Future<void> _loadLocalPackages() async {
    final dir = Directory(cacheDirectory);

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.yaml')) {
        try {
          final content = await entity.readAsString();
          final package = CapabilityPackage.fromYamlString(content);
          _cache[package.id] = package;
        } catch (e) {
          print('[CapabilityLoader] Failed to load ${entity.path}: $e');
        }
      }
    }

    print('[CapabilityLoader] Loaded ${_cache.length} cached packages');
  }

  /// Get a capability by ID, loading from cache or remote
  Future<CapabilityPackage?> get(String id) async {
    // Check in-memory cache
    if (_cache.containsKey(id)) {
      return _cache[id];
    }

    // Try to load from local file
    final localPackage = await _loadFromLocal(id);
    if (localPackage != null) {
      _cache[id] = localPackage;
      return localPackage;
    }

    // Try to fetch from remote
    final remotePackage = await _fetchFromRemote(id);
    if (remotePackage != null) {
      _cache[id] = remotePackage;
      await _saveToLocal(remotePackage);
      return remotePackage;
    }

    return null;
  }

  /// Check if a capability exists locally or remotely
  Future<bool> exists(String id) async {
    if (_cache.containsKey(id)) return true;

    final localPath = _getLocalPath(id);
    if (await File(localPath).exists()) return true;

    final manifest = await getManifest();
    return manifest?.packages.any((p) => p.id == id) ?? false;
  }

  /// Get all available capability IDs
  Future<List<String>> listAvailable() async {
    final ids = <String>{..._cache.keys};

    // Add from manifest
    final manifest = await getManifest();
    if (manifest != null) {
      ids.addAll(manifest.packages.map((p) => p.id));
    }

    return ids.toList()..sort();
  }

  /// Get remote manifest
  Future<CapabilityManifest?> getManifest({bool forceRefresh = false}) async {
    // Return cached if valid
    if (!forceRefresh &&
        _manifest != null &&
        _lastManifestFetch != null &&
        DateTime.now().difference(_lastManifestFetch!) < manifestCacheDuration) {
      return _manifest;
    }

    try {
      final response = await http.get(
        Uri.parse('$repositoryUrl/manifest.json'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _manifest = CapabilityManifest.fromJson(json);
        _lastManifestFetch = DateTime.now();

        // Save manifest locally
        await _saveManifestLocally();

        return _manifest;
      }
    } catch (e) {
      print('[CapabilityLoader] Failed to fetch manifest: $e');

      // Try to load cached manifest
      return await _loadLocalManifest();
    }

    return null;
  }

  /// Load package from local cache
  Future<CapabilityPackage?> _loadFromLocal(String id) async {
    final path = _getLocalPath(id);
    final file = File(path);

    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      return CapabilityPackage.fromYamlString(content);
    } catch (e) {
      print('[CapabilityLoader] Failed to load local package $id: $e');
      return null;
    }
  }

  /// Fetch package from remote repository
  Future<CapabilityPackage?> _fetchFromRemote(String id) async {
    try {
      // First check manifest for download URL
      final manifest = await getManifest();
      final info = manifest?.packages.firstWhere(
        (p) => p.id == id,
        orElse: () => throw Exception('Package not found in manifest'),
      );

      final url = info?.downloadUrl ?? '$repositoryUrl/packages/$id.yaml';

      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return CapabilityPackage.fromYamlString(response.body);
      }
    } catch (e) {
      print('[CapabilityLoader] Failed to fetch remote package $id: $e');
    }

    return null;
  }

  /// Save package to local cache
  Future<void> _saveToLocal(CapabilityPackage package) async {
    final path = _getLocalPath(package.id);
    final file = File(path);

    await file.parent.create(recursive: true);

    // Convert to YAML-like format for storage
    final content = _packageToYaml(package);
    await file.writeAsString(content);
  }

  /// Get local file path for a package
  String _getLocalPath(String id) {
    // Replace dots with slashes for nested directories
    final parts = id.split('.');
    final filename = '${parts.last}.yaml';
    final dirs = parts.sublist(0, parts.length - 1).join('/');

    if (dirs.isEmpty) {
      return '$cacheDirectory/$filename';
    }
    return '$cacheDirectory/$dirs/$filename';
  }

  /// Convert package to YAML string for storage
  String _packageToYaml(CapabilityPackage package) {
    final buffer = StringBuffer();

    buffer.writeln('id: ${package.id}');
    buffer.writeln('version: ${package.version}');
    buffer.writeln('name: ${package.name}');
    if (package.description != null) {
      buffer.writeln('description: ${package.description}');
    }
    if (package.author != null) {
      buffer.writeln('author: ${package.author}');
    }
    buffer.writeln('min_executor_version: ${package.minExecutorVersion}');
    buffer.writeln('platforms: [${package.platforms.map((p) => p.name).join(', ')}]');

    if (package.parameters.isNotEmpty) {
      buffer.writeln('parameters:');
      for (final param in package.parameters) {
        buffer.writeln('  - name: ${param.name}');
        buffer.writeln('    type: ${param.type.name}');
        buffer.writeln('    required: ${param.required}');
        if (param.description != null) {
          buffer.writeln('    description: ${param.description}');
        }
      }
    }

    if (package.workflow.isNotEmpty) {
      buffer.writeln('workflow:');
      for (final action in package.workflow) {
        buffer.writeln('  - action: ${action.action}');
        if (action.params.isNotEmpty) {
          buffer.writeln('    params:');
          action.params.forEach((key, value) {
            buffer.writeln('      $key: "$value"');
          });
        }
      }
    }

    if (package.requiresExecutors.isNotEmpty) {
      buffer.writeln('requires_executors: [${package.requiresExecutors.join(', ')}]');
    }

    if (package.tags.isNotEmpty) {
      buffer.writeln('tags: [${package.tags.join(', ')}]');
    }

    return buffer.toString();
  }

  /// Save manifest locally for offline use
  Future<void> _saveManifestLocally() async {
    if (_manifest == null) return;

    final path = '$cacheDirectory/manifest.json';
    final file = File(path);

    await file.writeAsString(jsonEncode(_manifest!.toJson()));
  }

  /// Load manifest from local cache
  Future<CapabilityManifest?> _loadLocalManifest() async {
    final path = '$cacheDirectory/manifest.json';
    final file = File(path);

    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CapabilityManifest.fromJson(json);
    } catch (e) {
      print('[CapabilityLoader] Failed to load local manifest: $e');
      return null;
    }
  }

  /// Clear cached package
  void clearCache(String id) {
    _cache.remove(id);
  }

  /// Clear all cached packages
  void clearAllCache() {
    _cache.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'cachedPackages': _cache.length,
      'cacheDirectory': cacheDirectory,
      'repositoryUrl': repositoryUrl,
      'manifestCached': _manifest != null,
      'lastManifestFetch': _lastManifestFetch?.toIso8601String(),
    };
  }
}
