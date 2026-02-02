import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto_pkg;

/// Represents a paired device
class PairedDevice {
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime pairedAt;
  final DateTime lastSeen;
  final String sharedSecret;
  final Map<String, bool> permissions;

  PairedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.pairedAt,
    required this.lastSeen,
    required this.sharedSecret,
    this.permissions = const {},
  });

  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    return PairedDevice(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      platform: json['platform'] as String,
      pairedAt: DateTime.parse(json['pairedAt'] as String),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      sharedSecret: json['sharedSecret'] as String,
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'pairedAt': pairedAt.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'sharedSecret': sharedSecret,
    'permissions': permissions,
  };

  PairedDevice copyWith({
    DateTime? lastSeen,
    Map<String, bool>? permissions,
  }) {
    return PairedDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      pairedAt: pairedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      sharedSecret: sharedSecret,
      permissions: permissions ?? this.permissions,
    );
  }
}

/// Pairing request data
class PairingRequest {
  final String pairingCode;
  final String hostDeviceId;
  final String hostName;
  final int port;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? tempSecret;

  PairingRequest({
    required this.pairingCode,
    required this.hostDeviceId,
    required this.hostName,
    required this.port,
    required this.createdAt,
    required this.expiresAt,
    this.tempSecret,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String toQRData() {
    final data = {
      'code': pairingCode,
      'host': hostDeviceId,
      'name': hostName,
      'port': port,
      'ts': createdAt.millisecondsSinceEpoch,
      'secret': tempSecret,
    };
    return 'opencli://pair?data=${base64Encode(utf8.encode(jsonEncode(data)))}';
  }

  Map<String, dynamic> toJson() => {
    'pairingCode': pairingCode,
    'hostDeviceId': hostDeviceId,
    'hostName': hostName,
    'port': port,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };
}

/// Manages device pairing and authentication
class DevicePairingManager {
  final String storageDir;
  final Duration pairingCodeValidity;

  final Map<String, PairedDevice> _pairedDevices = {};
  final Map<String, PairingRequest> _pendingPairings = {};

  DevicePairingManager({
    String? storageDir,
    this.pairingCodeValidity = const Duration(minutes: 5),
  }) : storageDir = storageDir ?? _defaultStorageDir();

  static String _defaultStorageDir() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.opencli/security';
  }

  /// Initialize and load paired devices
  Future<void> initialize() async {
    final dir = Directory(storageDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _loadPairedDevices();
    print('[DevicePairing] Loaded ${_pairedDevices.length} paired devices');
  }

  /// Load paired devices from storage
  Future<void> _loadPairedDevices() async {
    final file = File('$storageDir/paired_devices.json');
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content);

      for (final item in data) {
        final device = PairedDevice.fromJson(item as Map<String, dynamic>);
        _pairedDevices[device.deviceId] = device;
      }
    } catch (e) {
      print('[DevicePairing] Failed to load paired devices: $e');
    }
  }

  /// Save paired devices to storage
  Future<void> _savePairedDevices() async {
    final file = File('$storageDir/paired_devices.json');
    final data = _pairedDevices.values.map((d) => d.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  /// Generate a new pairing request
  PairingRequest generatePairingRequest({
    required String hostDeviceId,
    required String hostName,
    required int port,
  }) {
    // Generate 6-digit pairing code
    final code = _generatePairingCode();

    // Generate temporary secret for initial handshake
    final tempSecret = _generateSecret(32);

    final request = PairingRequest(
      pairingCode: code,
      hostDeviceId: hostDeviceId,
      hostName: hostName,
      port: port,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(pairingCodeValidity),
      tempSecret: tempSecret,
    );

    _pendingPairings[code] = request;

    // Cleanup expired pairings
    _cleanupExpiredPairings();

    return request;
  }

  /// Generate 6-digit pairing code
  String _generatePairingCode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  /// Generate secure random secret
  String _generateSecret(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Cleanup expired pairing requests
  void _cleanupExpiredPairings() {
    _pendingPairings.removeWhere((_, req) => req.isExpired);
  }

  /// Complete pairing with a device
  Future<PairedDevice?> completePairing({
    required String pairingCode,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    _cleanupExpiredPairings();

    final request = _pendingPairings[pairingCode];
    if (request == null) {
      print('[DevicePairing] Invalid or expired pairing code: $pairingCode');
      return null;
    }

    // Generate shared secret for this device
    final sharedSecret = _generateSecret(32);

    final device = PairedDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      pairedAt: DateTime.now(),
      lastSeen: DateTime.now(),
      sharedSecret: sharedSecret,
      permissions: _getDefaultPermissions(),
    );

    _pairedDevices[deviceId] = device;
    _pendingPairings.remove(pairingCode);

    await _savePairedDevices();

    print('[DevicePairing] Paired new device: $deviceName ($deviceId)');
    return device;
  }

  /// Get default permissions for new devices
  Map<String, bool> _getDefaultPermissions() {
    return {
      'query': true,           // Read-only queries
      'open_app': true,        // Open applications
      'open_url': true,        // Open URLs
      'screenshot': true,      // Take screenshots
      'file_read': true,       // Read files
      'file_write': false,     // Write files (needs confirmation)
      'file_delete': false,    // Delete files (needs confirmation)
      'run_command': false,    // Run shell commands (needs confirmation)
      'close_app': false,      // Close applications (needs confirmation)
      'system_settings': false, // Modify system settings (needs confirmation)
    };
  }

  /// Verify device authentication
  bool verifyAuthentication(String deviceId, String authToken, int timestamp) {
    final device = _pairedDevices[deviceId];
    if (device == null) return false;

    // Check timestamp (allow 5 minute window)
    final tokenTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(tokenTime).abs();

    if (diff > const Duration(minutes: 5)) {
      print('[DevicePairing] Auth failed: timestamp too old');
      return false;
    }

    // Verify HMAC
    final expectedToken = _generateAuthToken(deviceId, device.sharedSecret, timestamp);
    if (authToken != expectedToken) {
      print('[DevicePairing] Auth failed: invalid token');
      return false;
    }

    // Update last seen
    _pairedDevices[deviceId] = device.copyWith(lastSeen: DateTime.now());
    _savePairedDevices();

    return true;
  }

  /// Generate auth token for verification
  String _generateAuthToken(String deviceId, String secret, int timestamp) {
    final data = '$deviceId:$timestamp:$secret';
    final bytes = utf8.encode(data);
    final digest = crypto_pkg.sha256.convert(bytes);
    return digest.toString();
  }

  /// Check if device is paired
  bool isPaired(String deviceId) {
    return _pairedDevices.containsKey(deviceId);
  }

  /// Get paired device
  PairedDevice? getDevice(String deviceId) {
    return _pairedDevices[deviceId];
  }

  /// Get all paired devices
  List<PairedDevice> getAllDevices() {
    return _pairedDevices.values.toList();
  }

  /// Update device permissions
  Future<void> updatePermissions(String deviceId, Map<String, bool> permissions) async {
    final device = _pairedDevices[deviceId];
    if (device == null) return;

    _pairedDevices[deviceId] = device.copyWith(
      permissions: {...device.permissions, ...permissions},
    );

    await _savePairedDevices();
  }

  /// Check if device has permission for an action
  bool hasPermission(String deviceId, String permission) {
    final device = _pairedDevices[deviceId];
    if (device == null) return false;

    return device.permissions[permission] ?? false;
  }

  /// Unpair a device
  Future<void> unpairDevice(String deviceId) async {
    _pairedDevices.remove(deviceId);
    await _savePairedDevices();
    print('[DevicePairing] Unpaired device: $deviceId');
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'pairedDevices': _pairedDevices.length,
      'pendingPairings': _pendingPairings.length,
      'devices': _pairedDevices.values.map((d) => {
        'deviceId': d.deviceId.substring(0, 8) + '...',
        'deviceName': d.deviceName,
        'platform': d.platform,
        'lastSeen': d.lastSeen.toIso8601String(),
      }).toList(),
    };
  }
}

