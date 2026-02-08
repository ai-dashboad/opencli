/// Pairing manager for secure mobile device connections
///
/// Provides QR code-based pairing with time-limited pairing codes
/// and automatic trust for local network devices.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Pairing manager for mobile devices
class PairingManager {
  final Map<String, PairingCode> _activeCodes = {};
  final Map<String, PairedDevice> _pairedDevices = {};
  final Duration _codeTimeout;
  final int _maxDevices;
  final bool _autoTrustLocal;

  Timer? _cleanupTimer;

  PairingManager({
    Duration codeTimeout = const Duration(minutes: 5),
    int maxDevices = 5,
    bool autoTrustLocal = true,
  })  : _codeTimeout = codeTimeout,
        _maxDevices = maxDevices,
        _autoTrustLocal = autoTrustLocal {
    // Start periodic cleanup of expired codes
    _cleanupTimer = Timer.periodic(
      Duration(minutes: 1),
      (_) => _cleanupExpiredCodes(),
    );
  }

  /// Generate a new pairing code
  PairingCode generatePairingCode({
    String? deviceName,
    Map<String, dynamic>? metadata,
  }) {
    // Check device limit
    if (_pairedDevices.length >= _maxDevices) {
      throw PairingException(
        'Maximum number of devices reached ($_maxDevices)',
      );
    }

    // Generate random 6-digit code
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();

    // Generate unique pairing ID
    final pairingId = _generateId();

    // Create pairing code object
    final pairingCode = PairingCode(
      id: pairingId,
      code: code,
      deviceName: deviceName,
      metadata: metadata ?? {},
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(_codeTimeout),
    );

    // Store active code
    _activeCodes[pairingId] = pairingCode;

    print(
        '[PairingManager] Generated pairing code: $code (expires in ${_codeTimeout.inMinutes}m)');

    return pairingCode;
  }

  /// Verify and consume pairing code
  Future<PairedDevice> verifyPairingCode(
    String code,
    String deviceId,
    String deviceName,
    String ipAddress, {
    Map<String, dynamic>? metadata,
  }) async {
    // Find matching pairing code
    PairingCode? matchingCode;
    for (var pairingCode in _activeCodes.values) {
      if (pairingCode.code == code && !pairingCode.isExpired) {
        matchingCode = pairingCode;
        break;
      }
    }

    if (matchingCode == null) {
      throw PairingException('Invalid or expired pairing code');
    }

    // Check device limit again
    if (_pairedDevices.length >= _maxDevices) {
      throw PairingException(
        'Maximum number of devices reached ($_maxDevices)',
      );
    }

    // Check if device already paired
    if (_pairedDevices.containsKey(deviceId)) {
      throw PairingException('Device already paired');
    }

    // Generate access token
    final accessToken = _generateAccessToken(deviceId);

    // Create paired device
    final pairedDevice = PairedDevice(
      id: deviceId,
      name: deviceName,
      ipAddress: ipAddress,
      accessToken: accessToken,
      pairedAt: DateTime.now(),
      lastSeen: DateTime.now(),
      metadata: {...matchingCode.metadata, ...?metadata},
      isLocalNetwork: _isLocalNetwork(ipAddress),
      isTrusted: _autoTrustLocal && _isLocalNetwork(ipAddress),
    );

    // Store paired device
    _pairedDevices[deviceId] = pairedDevice;

    // Remove used pairing code
    _activeCodes.remove(matchingCode.id);

    print('[PairingManager] Device paired: $deviceName ($deviceId)');

    return pairedDevice;
  }

  /// Verify access token
  bool verifyAccessToken(String deviceId, String accessToken) {
    final device = _pairedDevices[deviceId];
    if (device == null) return false;

    // Update last seen
    device.lastSeen = DateTime.now();

    return device.accessToken == accessToken;
  }

  /// Unpair a device
  bool unpairDevice(String deviceId) {
    final removed = _pairedDevices.remove(deviceId);
    if (removed != null) {
      print('[PairingManager] Device unpaired: ${removed.name}');
      return true;
    }
    return false;
  }

  /// Get all paired devices
  List<PairedDevice> getPairedDevices() {
    return _pairedDevices.values.toList();
  }

  /// Get specific paired device
  PairedDevice? getPairedDevice(String deviceId) {
    return _pairedDevices[deviceId];
  }

  /// Check if device is paired
  bool isDevicePaired(String deviceId) {
    return _pairedDevices.containsKey(deviceId);
  }

  /// Revoke pairing code
  bool revokePairingCode(String pairingId) {
    return _activeCodes.remove(pairingId) != null;
  }

  /// Get all active pairing codes
  List<PairingCode> getActivePairingCodes() {
    return _activeCodes.values.where((code) => !code.isExpired).toList();
  }

  /// Generate QR code data URL
  String generateQRCodeData(
    PairingCode pairingCode, {
    required String serverUrl,
    required int port,
  }) {
    final qrData = {
      'type': 'opencli_pairing',
      'version': '1.0',
      'code': pairingCode.code,
      'pairing_id': pairingCode.id,
      'server_url': serverUrl,
      'port': port,
      'expires_at': pairingCode.expiresAt.toIso8601String(),
      'device_name': pairingCode.deviceName,
    };

    return jsonEncode(qrData);
  }

  /// Generate ASCII QR code for terminal display
  String generateASCIIQRCode(String data) {
    // This is a simplified version - in production, use a proper QR code library
    // For now, just return the data in a bordered box
    final lines = <String>[];
    final border = '─' * 50;

    lines.add('┌$border┐');
    lines.add('│                  QR Code Data                   │');
    lines.add('├$border┤');

    // Split data into chunks
    final chunks = _splitIntoChunks(data, 48);
    for (var chunk in chunks) {
      lines.add('│ ${chunk.padRight(48)} │');
    }

    lines.add('└$border┘');

    return lines.join('\n');
  }

  /// Cleanup expired pairing codes
  void _cleanupExpiredCodes() {
    final now = DateTime.now();
    _activeCodes.removeWhere((_, code) => code.expiresAt.isBefore(now));
  }

  /// Generate unique ID
  String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Generate access token
  String _generateAccessToken(String deviceId) {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = '$deviceId:$timestamp:${random.nextInt(1000000)}';
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return base64UrlEncode(hash.bytes).replaceAll('=', '');
  }

  /// Check if IP is local network
  bool _isLocalNetwork(String ipAddress) {
    // Check for private IP ranges
    if (ipAddress.startsWith('192.168.')) return true;
    if (ipAddress.startsWith('10.')) return true;
    if (ipAddress.startsWith('172.')) {
      final parts = ipAddress.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) {
          return true;
        }
      }
    }
    if (ipAddress == '127.0.0.1' || ipAddress == 'localhost') return true;
    return false;
  }

  /// Split string into chunks
  List<String> _splitIntoChunks(String text, int chunkSize) {
    final chunks = <String>[];
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      chunks.add(text.substring(i, end));
    }
    return chunks;
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _activeCodes.clear();
  }
}

/// Pairing code information
class PairingCode {
  final String id;
  final String code;
  final String? deviceName;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime expiresAt;

  PairingCode({
    required this.id,
    required this.code,
    this.deviceName,
    required this.metadata,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'device_name': deviceName,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_expired': isExpired,
      'time_remaining_seconds': timeRemaining.inSeconds,
    };
  }
}

/// Paired device information
class PairedDevice {
  final String id;
  final String name;
  final String ipAddress;
  final String accessToken;
  final DateTime pairedAt;
  DateTime lastSeen;
  final Map<String, dynamic> metadata;
  final bool isLocalNetwork;
  bool isTrusted;

  PairedDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.accessToken,
    required this.pairedAt,
    required this.lastSeen,
    required this.metadata,
    required this.isLocalNetwork,
    required this.isTrusted,
  });

  bool get isActive {
    final inactiveThreshold = Duration(hours: 24);
    return DateTime.now().difference(lastSeen) < inactiveThreshold;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip_address': ipAddress,
      'paired_at': pairedAt.toIso8601String(),
      'last_seen': lastSeen.toIso8601String(),
      'metadata': metadata,
      'is_local_network': isLocalNetwork,
      'is_trusted': isTrusted,
      'is_active': isActive,
    };
  }
}

/// Pairing exception
class PairingException implements Exception {
  final String message;

  PairingException(this.message);

  @override
  String toString() => 'PairingException: $message';
}
