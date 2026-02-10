/// Personal mode CLI commands
///
/// Simplified, user-friendly CLI commands for personal mode users.
library;

import 'personal_mode.dart';
import 'pairing_manager.dart';

/// Personal mode CLI command handler
class PersonalCLI {
  final PersonalMode personalMode;

  PersonalCLI(this.personalMode);

  /// Handle CLI command
  Future<CommandResult> handleCommand(String command, List<String> args) async {
    switch (command) {
      case 'status':
        return await _handleStatus();
      case 'pairing-code':
      case 'pair':
        return await _handlePairingCode();
      case 'devices':
        return await _handleDevices();
      case 'unpair':
        return await _handleUnpair(args);
      case 'start':
        return await _handleStart();
      case 'stop':
        return await _handleStop();
      case 'help':
        return _handleHelp();
      default:
        return CommandResult(
          success: false,
          message:
              'Unknown command: $command\nRun "opencli help" for available commands',
        );
    }
  }

  /// Handle status command
  Future<CommandResult> _handleStatus() async {
    final status = personalMode.getStatus();

    final output = StringBuffer();
    output.writeln('OpenCLI Personal Mode Status');
    output.writeln('═' * 50);
    output.writeln();
    output
        .writeln('Status: ${status['running'] ? '🟢 Running' : '🔴 Stopped'}');
    output.writeln('Port: ${status['port']}');
    output.writeln('Paired Devices: ${status['paired_devices']}');
    output.writeln('Active Connections: ${status['active_connections']}');
    output.writeln(
        'Auto-Discovery: ${status['discovery_enabled'] ? 'Enabled' : 'Disabled'}');
    output.writeln(
        'System Tray: ${status['tray_enabled'] ? 'Enabled' : 'Disabled'}');

    return CommandResult(success: true, message: output.toString());
  }

  /// Handle pairing code command
  Future<CommandResult> _handlePairingCode() async {
    try {
      final qrCode = personalMode.generatePairingQRCode();

      final output = StringBuffer();
      output.writeln();
      output.writeln('Mobile Device Pairing');
      output.writeln('═' * 50);
      output.writeln();
      output.writeln('Scan this QR code with the OpenCLI mobile app:');
      output.writeln();
      output.writeln(qrCode);
      output.writeln();
      output.writeln('Or use auto-discovery:');
      output.writeln('1. Open the OpenCLI app on your phone');
      output.writeln('2. Make sure your phone is on the same WiFi');
      output.writeln('3. The app will automatically discover this computer');
      output.writeln();
      output.writeln('Pairing code expires in 5 minutes');
      output.writeln();

      return CommandResult(success: true, message: output.toString());
    } catch (e) {
      return CommandResult(
        success: false,
        message: 'Failed to generate pairing code: $e',
      );
    }
  }

  /// Handle devices command
  Future<CommandResult> _handleDevices() async {
    final devices = personalMode.getPairedDevices();

    final output = StringBuffer();
    output.writeln('Paired Devices');
    output.writeln('═' * 50);
    output.writeln();

    if (devices.isEmpty) {
      output.writeln('No devices paired yet.');
      output.writeln();
      output.writeln('To pair a device, run: opencli pairing-code');
    } else {
      for (var device in devices) {
        final status = device.isActive ? '🟢 Active' : '🔴 Inactive';
        final trusted = device.isTrusted ? '🔒 Trusted' : '⚠️  Untrusted';

        output.writeln('${device.name}');
        output.writeln('  ID: ${device.id}');
        output.writeln('  IP: ${device.ipAddress}');
        output.writeln('  Status: $status');
        output.writeln('  Security: $trusted');
        output.writeln('  Paired: ${_formatDateTime(device.pairedAt)}');
        output.writeln('  Last Seen: ${_formatDateTime(device.lastSeen)}');
        output.writeln();
      }

      output.writeln(
          'Total: ${devices.length} device${devices.length > 1 ? 's' : ''}');
    }

    return CommandResult(success: true, message: output.toString());
  }

  /// Handle unpair command
  Future<CommandResult> _handleUnpair(List<String> args) async {
    if (args.isEmpty) {
      return CommandResult(
        success: false,
        message: 'Usage: opencli unpair <device_id>',
      );
    }

    final deviceId = args[0];
    final success = personalMode.unpairDevice(deviceId);

    if (success) {
      return CommandResult(
        success: true,
        message: 'Device unpaired successfully',
      );
    } else {
      return CommandResult(
        success: false,
        message: 'Device not found: $deviceId',
      );
    }
  }

  /// Handle start command
  Future<CommandResult> _handleStart() async {
    try {
      if (!personalMode.isInitialized) {
        final initResult = await personalMode.initialize();
        if (!initResult.success) {
          return CommandResult(
            success: false,
            message: 'Initialization failed: ${initResult.message}',
          );
        }
      }

      await personalMode.start();

      return CommandResult(
        success: true,
        message: '''
OpenCLI Personal Mode started successfully! 🎉

System tray icon should appear in your menu bar.
Mobile devices can now connect via auto-discovery or QR code.

Next steps:
  - View status:    opencli status
  - Pair device:    opencli pairing-code
  - View devices:   opencli devices
  - Stop daemon:    opencli stop

''',
      );
    } catch (e) {
      return CommandResult(
        success: false,
        message: 'Failed to start: $e',
      );
    }
  }

  /// Handle stop command
  Future<CommandResult> _handleStop() async {
    try {
      await personalMode.stop();

      return CommandResult(
        success: true,
        message: 'OpenCLI stopped',
      );
    } catch (e) {
      return CommandResult(
        success: false,
        message: 'Failed to stop: $e',
      );
    }
  }

  /// Handle help command
  CommandResult _handleHelp() {
    final help = '''
OpenCLI Personal Mode - Simple Commands

DAEMON CONTROL:
  opencli start              Start the OpenCLI daemon
  opencli stop               Stop the OpenCLI daemon
  opencli status             Show current status

MOBILE PAIRING:
  opencli pairing-code       Generate QR code for mobile pairing
  opencli devices            List all paired devices
  opencli unpair <id>        Unpair a device

QUICK TASKS:
  opencli screenshot         Take a screenshot
  opencli open <app>         Open an application
  opencli file <path>        File operations

HELP:
  opencli help               Show this help message
  opencli version            Show version information

For more help, visit: https://docs.opencli.dev
''';

    return CommandResult(success: true, message: help);
  }

  /// Format datetime for display
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}

/// Command execution result
class CommandResult {
  final bool success;
  final String message;

  CommandResult({
    required this.success,
    required this.message,
  });
}
