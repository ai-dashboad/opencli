/// Personal mode integration module
///
/// Provides zero-configuration setup for personal users with automatic
/// discovery, pairing, and system tray integration.
library;

import 'dart:async';
import 'auto_discovery.dart';
import 'pairing_manager.dart';
import 'tray_application.dart';
import 'first_run.dart';
import 'mobile_connection_manager.dart';

/// Personal mode manager
class PersonalMode {
  final PersonalModeConfig config;

  late final FirstRunManager _firstRun;
  late final PairingManager _pairingManager;
  late final AutoDiscoveryService _discoveryService;
  late final TrayApplication _trayApp;
  late final MobileConnectionManager _connectionManager;

  bool _isInitialized = false;
  bool _isRunning = false;

  PersonalMode({PersonalModeConfig? config})
      : config = config ?? PersonalModeConfig();

  /// Initialize personal mode
  Future<InitializationResult> initialize() async {
    if (_isInitialized) {
      return InitializationResult(
        success: true,
        message: 'Already initialized',
      );
    }

    try {
      print('[PersonalMode] Initializing...');

      // Initialize first-run manager
      _firstRun = FirstRunManager();

      // Check if first run
      if (_firstRun.isFirstRun()) {
        print('[PersonalMode] First run detected, setting up...');
        final result = await _firstRun.initialize();

        if (!result.success) {
          return InitializationResult(
            success: false,
            message: 'First-run setup failed: ${result.message}',
          );
        }

        print('[PersonalMode] First-run setup complete');
        print(result.message);
      }

      // Initialize components
      _pairingManager = PairingManager(
        codeTimeout: Duration(minutes: config.pairingTimeoutMinutes),
        maxDevices: config.maxDevices,
        autoTrustLocal: config.autoTrustLocal,
      );

      _discoveryService = AutoDiscoveryService(
        serviceName: config.discoveryName,
        port: config.port,
        metadata: {
          'version': '1.0.0',
          'mode': 'personal',
          'features': 'desktop,mobile,ai',
        },
      );

      _trayApp = TrayApplication(
        appName: 'OpenCLI',
        version: '1.0.0',
        config: TrayConfig(
          startAtLogin: config.autoStart,
          showNotifications: config.showNotifications,
          minimizeToTray: config.minimizeToTray,
        ),
      );

      _connectionManager = MobileConnectionManager(
        port: config.port,
        pairingManager: _PairingManagerAdapter(_pairingManager),
        discoveryService: _AutoDiscoveryAdapter(_discoveryService),
      );

      _isInitialized = true;

      print('[PersonalMode] Initialization complete');

      return InitializationResult(
        success: true,
        message: 'Personal mode initialized successfully',
      );
    } catch (e) {
      print('[PersonalMode] Initialization failed: $e');
      return InitializationResult(
        success: false,
        message: 'Initialization failed: $e',
      );
    }
  }

  /// Start personal mode services
  Future<void> start() async {
    if (!_isInitialized) {
      throw PersonalModeException('Not initialized. Call initialize() first.');
    }

    if (_isRunning) return;

    try {
      print('[PersonalMode] Starting services...');

      // Start discovery service
      await _discoveryService.start();

      // Start mobile connection manager
      await _connectionManager.start();

      // Start system tray
      if (config.enableTray) {
        await _trayApp.start();
      }

      // Listen to connection events
      _connectionManager.connectionEvents.listen(_handleConnectionEvent);

      _isRunning = true;

      print('[PersonalMode] All services started');
      print('[PersonalMode] Ready for mobile connections on port ${config.port}');
    } catch (e) {
      print('[PersonalMode] Failed to start: $e');
      rethrow;
    }
  }

  /// Stop personal mode services
  Future<void> stop() async {
    if (!_isRunning) return;

    print('[PersonalMode] Stopping services...');

    // Stop mobile connection manager
    await _connectionManager.stop();

    // Stop discovery service
    await _discoveryService.stop();

    // Stop system tray
    await _trayApp.stop();

    _isRunning = false;

    print('[PersonalMode] All services stopped');
  }

  /// Generate pairing code
  PairingCode generatePairingCode() {
    if (!_isInitialized) {
      throw PersonalModeException('Not initialized');
    }

    return _pairingManager.generatePairingCode();
  }

  /// Generate QR code for pairing
  String generatePairingQRCode() {
    final code = generatePairingCode();

    final qrData = _pairingManager.generateQRCodeData(
      code,
      serverUrl: _discoveryService.serviceName,
      port: config.port,
    );

    return _pairingManager.generateASCIIQRCode(qrData);
  }

  /// Get paired devices
  List<PairedDevice> getPairedDevices() {
    if (!_isInitialized) return [];
    return _pairingManager.getPairedDevices();
  }

  /// Unpair device
  bool unpairDevice(String deviceId) {
    if (!_isInitialized) return false;
    return _pairingManager.unpairDevice(deviceId);
  }

  /// Get connection status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'running': _isRunning,
      'port': config.port,
      'paired_devices': _isInitialized ? _pairingManager.getPairedDevices().length : 0,
      'active_connections': _isRunning ? _connectionManager.getActiveConnections().length : 0,
      'discovery_enabled': _discoveryService.isRunning,
      'tray_enabled': _trayApp.isRunning,
    };
  }

  /// Handle connection events
  void _handleConnectionEvent(ConnectionEvent event) {
    switch (event.type) {
      case ConnectionEventType.connected:
        print('[PersonalMode] Device connected: ${event.deviceId}');
        if (config.showNotifications) {
          _trayApp.showNotification(
            title: 'Device Connected',
            message: 'Mobile device ${event.deviceId} connected',
            type: TrayNotificationType.success,
          );
        }
        break;

      case ConnectionEventType.disconnected:
        print('[PersonalMode] Device disconnected: ${event.deviceId}');
        break;

      case ConnectionEventType.taskReceived:
        print('[PersonalMode] Task received from ${event.deviceId}');
        // Handle task execution (would integrate with task queue)
        break;

      case ConnectionEventType.error:
        print('[PersonalMode] Connection error: ${event.deviceId}');
        break;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    _pairingManager.dispose();
    await _trayApp.dispose();
  }

  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
}

/// Personal mode configuration
class PersonalModeConfig {
  final int port;
  final String discoveryName;
  final int pairingTimeoutMinutes;
  final int maxDevices;
  final bool autoTrustLocal;
  final bool autoStart;
  final bool enableTray;
  final bool showNotifications;
  final bool minimizeToTray;

  PersonalModeConfig({
    this.port = 8765,
    String? discoveryName,
    this.pairingTimeoutMinutes = 5,
    this.maxDevices = 5,
    this.autoTrustLocal = true,
    this.autoStart = true,
    this.enableTray = true,
    this.showNotifications = true,
    this.minimizeToTray = true,
  }) : discoveryName = discoveryName ?? _getDefaultDiscoveryName();

  static String _getDefaultDiscoveryName() {
    // Would use actual hostname
    return 'OpenCLI-Personal';
  }
}

/// Initialization result
class InitializationResult {
  final bool success;
  final String message;

  InitializationResult({
    required this.success,
    required this.message,
  });
}

/// Personal mode exception
class PersonalModeException implements Exception {
  final String message;

  PersonalModeException(this.message);

  @override
  String toString() => 'PersonalModeException: $message';
}

// Adapter classes to bridge interfaces
class _PairingManagerAdapter implements PairingManagerRef {
  final PairingManager _manager;

  _PairingManagerAdapter(this._manager);

  @override
  Future<dynamic> verifyPairingCode(
    String code,
    String deviceId,
    String deviceName,
    String ipAddress, {
    Map<String, dynamic>? metadata,
  }) {
    return _manager.verifyPairingCode(
      code,
      deviceId,
      deviceName,
      ipAddress,
      metadata: metadata,
    );
  }

  @override
  bool verifyAccessToken(String deviceId, String accessToken) {
    return _manager.verifyAccessToken(deviceId, accessToken);
  }
}

class _AutoDiscoveryAdapter implements AutoDiscoveryServiceRef {
  final AutoDiscoveryService _service;

  _AutoDiscoveryAdapter(this._service);

  @override
  Future<void> start() => _service.start();

  @override
  Future<void> stop() => _service.stop();
}
