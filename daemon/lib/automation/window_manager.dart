import 'dart:io';
import 'dart:convert';
import 'package:opencli_daemon/automation/types.dart';

/// Window management - List, activate, minimize, maximize, close windows
class WindowManager {
  /// Get all windows
  Future<List<Window>> getWindows() async {
    if (Platform.isMacOS) {
      return await _getMacOSWindows();
    } else if (Platform.isLinux) {
      return await _getLinuxWindows();
    } else if (Platform.isWindows) {
      return await _getWindowsWindows();
    }

    return [];
  }

  /// Get active window
  Future<Window?> getActiveWindow() async {
    final windows = await getWindows();
    return windows.firstWhere(
      (w) => w.isActive,
      orElse: () => Window(
        id: '',
        title: '',
        appName: '',
        bounds: Rectangle(x: 0, y: 0, width: 0, height: 0),
      ),
    );
  }

  /// Activate window by ID
  Future<void> activateWindow(String windowId) async {
    if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to set frontmost of process id $windowId to true'
      ]);
    } else if (Platform.isLinux) {
      await Process.run('wmctrl', ['-ia', windowId]);
    }
  }

  /// Minimize window
  Future<void> minimizeWindow(String windowId) async {
    if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to set miniaturized of window id $windowId to true'
      ]);
    } else if (Platform.isLinux) {
      await Process.run('wmctrl', ['-ir', windowId, '-b', 'add,hidden']);
    }
  }

  /// Maximize window
  Future<void> maximizeWindow(String windowId) async {
    if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to set bounds of window id $windowId to {0, 0, 1920, 1080}'
      ]);
    } else if (Platform.isLinux) {
      await Process.run('wmctrl', ['-ir', windowId, '-b', 'add,maximized_vert,maximized_horz']);
    }
  }

  /// Close window
  Future<void> closeWindow(String windowId) async {
    if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to close window id $windowId'
      ]);
    } else if (Platform.isLinux) {
      await Process.run('wmctrl', ['-ic', windowId]);
    }
  }

  /// Resize window
  Future<void> resizeWindow(String windowId, int width, int height) async {
    if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to set size of window id $windowId to {$width, $height}'
      ]);
    } else if (Platform.isLinux) {
      await Process.run('wmctrl', ['-ir', windowId, '-e', '0,-1,-1,$width,$height']);
    }
  }

  /// Move window
  Future<void> moveWindow(String windowId, int x, int y) async {
    if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to set position of window id $windowId to {$x, $y}'
      ]);
    } else if (Platform.isLinux) {
      await Process.run('wmctrl', ['-ir', windowId, '-e', '0,$x,$y,-1,-1']);
    }
  }

  /// Get windows by app name
  Future<List<Window>> getWindowsByApp(String appName) async {
    final windows = await getWindows();
    return windows.where((w) =>
      w.appName.toLowerCase().contains(appName.toLowerCase())
    ).toList();
  }

  // Platform-specific implementations

  Future<List<Window>> _getMacOSWindows() async {
    final script = '''
    tell application "System Events"
      set windowList to {}
      repeat with proc in (every process whose background only is false)
        try
          repeat with win in (every window of proc)
            set windowInfo to {¬
              id of win, ¬
              name of win, ¬
              name of proc, ¬
              position of win, ¬
              size of win, ¬
              miniaturized of win, ¬
              zoomed of win, ¬
              (frontmost of proc) as boolean¬
            }
            set end of windowList to windowInfo
          end repeat
        end try
      end repeat
      return windowList
    end tell
    ''';

    final result = await Process.run('osascript', ['-e', script]);
    final output = result.stdout.toString();

    // Parse AppleScript output
    // This is a simplified parser - actual implementation would be more robust
    final windows = <Window>[];

    // TODO: Implement proper AppleScript list parsing

    return windows;
  }

  Future<List<Window>> _getLinuxWindows() async {
    final result = await Process.run('wmctrl', ['-lGpx']);
    final lines = result.stdout.toString().split('\n');

    final windows = <Window>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 7) {
        windows.add(Window(
          id: parts[0],
          title: parts.sublist(7).join(' '),
          appName: parts[2],
          bounds: Rectangle(
            x: int.tryParse(parts[3]) ?? 0,
            y: int.tryParse(parts[4]) ?? 0,
            width: int.tryParse(parts[5]) ?? 0,
            height: int.tryParse(parts[6]) ?? 0,
          ),
        ));
      }
    }

    return windows;
  }

  Future<List<Window>> _getWindowsWindows() async {
    // Use PowerShell to get window information
    final script = '''
    Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object Id, ProcessName, MainWindowTitle | ConvertTo-Json
    ''';

    final result = await Process.run('powershell', ['-Command', script]);
    final output = result.stdout.toString();

    final windows = <Window>[];

    try {
      final List<dynamic> windowData = jsonDecode(output);

      for (final data in windowData) {
        windows.add(Window(
          id: data['Id'].toString(),
          title: data['MainWindowTitle'] ?? '',
          appName: data['ProcessName'] ?? '',
          bounds: Rectangle(x: 0, y: 0, width: 0, height: 0),
        ));
      }
    } catch (e) {
      print('Error parsing Windows window data: $e');
    }

    return windows;
  }
}

