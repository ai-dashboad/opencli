import 'dart:async';
import 'capability_registry.dart';
import 'capability_loader.dart';
import 'capability_schema.dart';

/// Configuration for capability updates
class CapabilityUpdateConfig {
  /// Whether automatic updates are enabled
  final bool autoUpdate;

  /// Update check interval
  final Duration checkInterval;

  /// Whether to download updates immediately or on-demand
  final bool downloadImmediately;

  /// List of capabilities to never auto-update
  final List<String> excludeFromAutoUpdate;

  const CapabilityUpdateConfig({
    this.autoUpdate = true,
    this.checkInterval = const Duration(hours: 1),
    this.downloadImmediately = false,
    this.excludeFromAutoUpdate = const [],
  });
}

/// Update status for a capability
class CapabilityUpdateStatus {
  final String capabilityId;
  final String currentVersion;
  final String? availableVersion;
  final bool updateAvailable;
  final DateTime? lastChecked;

  const CapabilityUpdateStatus({
    required this.capabilityId,
    required this.currentVersion,
    this.availableVersion,
    required this.updateAvailable,
    this.lastChecked,
  });

  Map<String, dynamic> toJson() => {
        'capabilityId': capabilityId,
        'currentVersion': currentVersion,
        'availableVersion': availableVersion,
        'updateAvailable': updateAvailable,
        'lastChecked': lastChecked?.toIso8601String(),
      };
}

/// Manages capability updates
class CapabilityUpdater {
  final CapabilityRegistry _registry;
  final CapabilityLoader _loader;
  final CapabilityUpdateConfig config;

  Timer? _updateTimer;
  DateTime? _lastUpdateCheck;

  /// Pending updates
  final Map<String, CapabilityPackageInfo> _pendingUpdates = {};

  /// Update listeners
  final List<void Function(List<CapabilityUpdateStatus>)> _listeners = [];

  CapabilityUpdater({
    required CapabilityRegistry registry,
    required CapabilityLoader loader,
    this.config = const CapabilityUpdateConfig(),
  })  : _registry = registry,
        _loader = loader;

  /// Start the auto-update timer
  void start() {
    if (!config.autoUpdate) {
      print('[CapabilityUpdater] Auto-update disabled');
      return;
    }

    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(config.checkInterval, (_) {
      checkForUpdates();
    });

    // Initial check
    checkForUpdates();

    print(
        '[CapabilityUpdater] Started with ${config.checkInterval.inMinutes} minute interval');
  }

  /// Stop the auto-update timer
  void stop() {
    _updateTimer?.cancel();
    _updateTimer = null;
    print('[CapabilityUpdater] Stopped');
  }

  /// Check for available updates
  Future<List<CapabilityUpdateStatus>> checkForUpdates() async {
    print('[CapabilityUpdater] Checking for updates...');
    _lastUpdateCheck = DateTime.now();

    final updates = <CapabilityUpdateStatus>[];

    try {
      // Get latest manifest
      final manifest = await _loader.getManifest(forceRefresh: true);
      if (manifest == null) {
        print('[CapabilityUpdater] Failed to fetch manifest');
        return updates;
      }

      // Compare with registered capabilities
      for (final info in manifest.packages) {
        final current = await _registry.get(info.id);

        if (current == null) {
          // New capability available
          updates.add(CapabilityUpdateStatus(
            capabilityId: info.id,
            currentVersion: 'not installed',
            availableVersion: info.version,
            updateAvailable: true,
            lastChecked: _lastUpdateCheck,
          ));

          _pendingUpdates[info.id] = info;
        } else if (_isNewerVersion(info.version, current.version)) {
          // Update available
          updates.add(CapabilityUpdateStatus(
            capabilityId: info.id,
            currentVersion: current.version,
            availableVersion: info.version,
            updateAvailable: true,
            lastChecked: _lastUpdateCheck,
          ));

          if (!config.excludeFromAutoUpdate.contains(info.id)) {
            _pendingUpdates[info.id] = info;
          }
        } else {
          // Already up to date
          updates.add(CapabilityUpdateStatus(
            capabilityId: info.id,
            currentVersion: current.version,
            updateAvailable: false,
            lastChecked: _lastUpdateCheck,
          ));
        }
      }

      // Auto-download if configured
      if (config.downloadImmediately && _pendingUpdates.isNotEmpty) {
        await applyUpdates();
      }

      // Notify listeners
      for (final listener in _listeners) {
        listener(updates);
      }

      print(
          '[CapabilityUpdater] Found ${_pendingUpdates.length} updates available');
    } catch (e) {
      print('[CapabilityUpdater] Error checking updates: $e');
    }

    return updates;
  }

  /// Apply pending updates
  Future<List<String>> applyUpdates([List<String>? capabilityIds]) async {
    final toUpdate = capabilityIds ?? _pendingUpdates.keys.toList();
    final updated = <String>[];

    for (final id in toUpdate) {
      try {
        final package = await _loader.get(id);
        if (package != null) {
          _registry.register(package);
          _pendingUpdates.remove(id);
          updated.add(id);
          print('[CapabilityUpdater] Updated $id to ${package.version}');
        }
      } catch (e) {
        print('[CapabilityUpdater] Failed to update $id: $e');
      }
    }

    return updated;
  }

  /// Update a specific capability
  Future<bool> updateCapability(String id) async {
    try {
      // Clear cache to force fresh download
      _loader.clearCache(id);

      final package = await _loader.get(id);
      if (package != null) {
        _registry.register(package);
        _pendingUpdates.remove(id);
        return true;
      }
    } catch (e) {
      print('[CapabilityUpdater] Failed to update $id: $e');
    }

    return false;
  }

  /// Check version comparison
  bool _isNewerVersion(String available, String current) {
    final availableParts = available.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final a = i < availableParts.length ? (availableParts[i] ?? 0) : 0;
      final c = i < currentParts.length ? (currentParts[i] ?? 0) : 0;

      if (a > c) return true;
      if (a < c) return false;
    }

    return false;
  }

  /// Get pending updates
  List<CapabilityPackageInfo> getPendingUpdates() {
    return _pendingUpdates.values.toList();
  }

  /// Add update listener
  void addListener(void Function(List<CapabilityUpdateStatus>) listener) {
    _listeners.add(listener);
  }

  /// Remove update listener
  void removeListener(void Function(List<CapabilityUpdateStatus>) listener) {
    _listeners.remove(listener);
  }

  /// Get update status
  Map<String, dynamic> getStatus() {
    return {
      'autoUpdateEnabled': config.autoUpdate,
      'checkInterval': config.checkInterval.inMinutes,
      'lastCheck': _lastUpdateCheck?.toIso8601String(),
      'pendingUpdates': _pendingUpdates.length,
      'pendingList': _pendingUpdates.keys.toList(),
    };
  }
}
