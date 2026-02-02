import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Service to manage global keyboard shortcuts
class HotkeyService {
  HotKey? _showWindowHotkey;

  /// Initialize global hotkeys
  Future<void> init() async {
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return;
    }

    try {
      // Register Cmd/Ctrl + Shift + O to show window
      _showWindowHotkey = HotKey(
        key: LogicalKeyboardKey.keyO,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift], // Cmd+Shift on macOS
        scope: HotKeyScope.system,
      );

      await hotKeyManager.register(
        _showWindowHotkey!,
        keyDownHandler: (hotKey) async {
          // Show and focus window when hotkey is pressed
          await windowManager.show();
          await windowManager.focus();
        },
      );

      debugPrint('✅ Global hotkey registered: Cmd/Ctrl+Shift+O');
    } catch (e) {
      debugPrint('Failed to register hotkey: $e');
    }
  }

  /// Unregister all hotkeys
  Future<void> dispose() async {
    if (_showWindowHotkey != null) {
      try {
        await hotKeyManager.unregister(_showWindowHotkey!);
        debugPrint('✅ Global hotkey unregistered');
      } catch (e) {
        debugPrint('Failed to unregister hotkey: $e');
      }
    }
  }
}
