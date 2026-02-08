/// OpenCLI Security Module
///
/// Provides device pairing, authentication, and permission management
/// for secure remote control operations.
///
/// Usage:
/// ```dart
/// final pairingManager = DevicePairingManager();
/// await pairingManager.initialize();
///
/// // Generate pairing request
/// final request = pairingManager.generatePairingRequest(
///   hostDeviceId: 'host-123',
///   hostName: 'My MacBook',
///   port: 9876,
/// );
/// print('Scan QR: ${request.toQRData()}');
///
/// // Complete pairing when mobile scans code
/// final device = await pairingManager.completePairing(
///   pairingCode: '123456',
///   deviceId: 'mobile-456',
///   deviceName: 'iPhone',
///   platform: 'ios',
/// );
///
/// // Check permissions
/// final permissionManager = PermissionManager(pairingManager: pairingManager);
/// final result = await permissionManager.checkPermission(
///   deviceId: 'mobile-456',
///   operation: 'run_command',
///   params: {'command': 'ls'},
/// );
///
/// if (result.requiresConfirmation) {
///   final confirmed = await permissionManager.requestConfirmation(
///     deviceId: 'mobile-456',
///     operation: 'run_command',
///     details: {'command': 'ls'},
///   );
/// }
/// ```

library security;

export 'device_pairing.dart';
export 'permission_manager.dart';
