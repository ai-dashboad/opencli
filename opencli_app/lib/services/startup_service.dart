import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to manage application auto-start on boot
class StartupService {
  bool _isEnabled = false;

  /// Check if launch at startup is enabled
  bool get isEnabled => _isEnabled;

  /// Initialize the startup service
  Future<void> init() async {
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return;
    }

    try {
      // Get package info for app name
      final packageInfo = await PackageInfo.fromPlatform();
      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );

      // Check if already enabled
      _isEnabled = await launchAtStartup.isEnabled();
      debugPrint('Launch at startup status: $_isEnabled');
    } catch (e) {
      debugPrint('Failed to initialize startup service: $e');
    }
  }

  /// Enable launch at startup
  Future<bool> enable() async {
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return false;
    }

    try {
      await launchAtStartup.enable();
      _isEnabled = true;
      debugPrint('✅ Launch at startup enabled');
      return true;
    } catch (e) {
      debugPrint('Failed to enable launch at startup: $e');
      return false;
    }
  }

  /// Disable launch at startup
  Future<bool> disable() async {
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return false;
    }

    try {
      await launchAtStartup.disable();
      _isEnabled = false;
      debugPrint('✅ Launch at startup disabled');
      return true;
    } catch (e) {
      debugPrint('Failed to disable launch at startup: $e');
      return false;
    }
  }

  /// Toggle launch at startup
  Future<bool> toggle() async {
    if (_isEnabled) {
      return await disable();
    } else {
      return await enable();
    }
  }
}
