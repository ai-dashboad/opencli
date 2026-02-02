import 'dart:io';
import 'package:opencli_daemon/automation/input_controller.dart';
import 'package:opencli_daemon/automation/process_manager.dart';
import 'package:opencli_daemon/automation/window_manager.dart';
import 'package:opencli_daemon/automation/types.dart';

/// Desktop automation controller - Full computer control
class DesktopController {
  final ProcessManager processManager;
  final InputController inputController;
  final WindowManager windowManager;

  DesktopController()
      : processManager = ProcessManager(),
        inputController = InputController(),
        windowManager = WindowManager();

  // ==================== Application Control ====================

  /// Open application by name
  Future<void> openApplication(String appName) async {
    if (Platform.isMacOS) {
      await Process.run('open', ['-a', appName]);
    } else if (Platform.isWindows) {
      await Process.run('start', [appName]);
    } else if (Platform.isLinux) {
      await Process.run('gtk-launch', [appName]);
    }
  }

  /// Close application by name
  Future<void> closeApplication(String appName) async {
    if (Platform.isMacOS) {
      await Process.run('killall', [appName]);
    } else if (Platform.isWindows) {
      await Process.run('taskkill', ['/IM', '$appName.exe', '/F']);
    } else if (Platform.isLinux) {
      await Process.run('pkill', [appName]);
    }
  }

  /// Check if application is running
  Future<bool> isApplicationRunning(String appName) async {
    final processes = await processManager.listProcesses();
    return processes.any((p) => p.name.toLowerCase().contains(appName.toLowerCase()));
  }

  // ==================== File System Operations ====================

  /// Create directory
  Future<void> createDirectory(String path) async {
    await Directory(path).create(recursive: true);
  }

  /// Copy file
  Future<void> copyFile(String source, String destination) async {
    await File(source).copy(destination);
  }

  /// Move file
  Future<void> moveFile(String source, String destination) async {
    await File(source).rename(destination);
  }

  /// Delete file
  Future<void> deleteFile(String path) async {
    await File(path).delete();
  }

  /// List directory contents
  Future<List<FileSystemEntity>> listDirectory(String path) async {
    return await Directory(path).list().toList();
  }

  /// Read file content
  Future<String> readFile(String path) async {
    return await File(path).readAsString();
  }

  /// Write file content
  Future<void> writeFile(String path, String content) async {
    await File(path).writeAsString(content);
  }

  // ==================== System Control ====================

  /// Execute shell command
  Future<CommandResult> executeCommand(
    String command, {
    List<String> args = const [],
    String? workingDirectory,
  }) async {
    final result = await Process.run(
      command,
      args,
      workingDirectory: workingDirectory,
    );

    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }

  /// Get system information
  Future<SystemInfo> getSystemInfo() async {
    return SystemInfo(
      operatingSystem: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      numberOfProcessors: Platform.numberOfProcessors,
      pathSeparator: Platform.pathSeparator,
      localeName: Platform.localeName,
    );
  }

  /// Shutdown computer
  Future<void> shutdown({int delaySeconds = 0}) async {
    if (Platform.isMacOS || Platform.isLinux) {
      await Process.run('shutdown', ['-h', '+$delaySeconds']);
    } else if (Platform.isWindows) {
      await Process.run('shutdown', ['/s', '/t', delaySeconds.toString()]);
    }
  }

  /// Restart computer
  Future<void> restart({int delaySeconds = 0}) async {
    if (Platform.isMacOS || Platform.isLinux) {
      await Process.run('shutdown', ['-r', '+$delaySeconds']);
    } else if (Platform.isWindows) {
      await Process.run('shutdown', ['/r', '/t', delaySeconds.toString()]);
    }
  }

  /// Sleep computer
  Future<void> sleep() async {
    if (Platform.isMacOS) {
      await Process.run('pmset', ['sleepnow']);
    } else if (Platform.isLinux) {
      await Process.run('systemctl', ['suspend']);
    } else if (Platform.isWindows) {
      await Process.run('rundll32.exe', ['powrprof.dll,SetSuspendState', '0,1,0']);
    }
  }

  // ==================== Network Operations ====================

  /// Get network interfaces
  Future<List<NetworkInterface>> getNetworkInterfaces() async {
    return await NetworkInterface.list();
  }

  /// Check internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ==================== UI Automation ====================

  /// Click at coordinates
  Future<void> click(int x, int y) async {
    await inputController.clickMouse(x: x, y: y);
  }

  /// Double click at coordinates
  Future<void> doubleClick(int x, int y) async {
    await inputController.doubleClick(x: x, y: y);
  }

  /// Right click at coordinates
  Future<void> rightClick(int x, int y) async {
    await inputController.rightClick(x: x, y: y);
  }

  /// Type text
  Future<void> type(String text) async {
    await inputController.typeText(text);
  }

  /// Press key combination
  Future<void> pressKeys(List<String> keys) async {
    await inputController.pressKeys(keys);
  }

  /// Take screenshot
  Future<Screenshot> screenshot({Rectangle? region}) {
    return inputController.captureScreen(region: region);
  }

  /// Find image on screen
  Future<Point?> findImage(String templatePath) {
    return inputController.findImageOnScreen(templatePath);
  }

  /// Read text from screen using OCR
  Future<String> readTextFromScreen({Rectangle? region}) {
    return inputController.readTextFromScreen(region: region);
  }

  // ==================== Window Management ====================

  /// Get all windows
  Future<List<Window>> getWindows() async {
    return await windowManager.getWindows();
  }

  /// Get active window
  Future<Window?> getActiveWindow() async {
    return await windowManager.getActiveWindow();
  }

  /// Activate window
  Future<void> activateWindow(String windowId) async {
    await windowManager.activateWindow(windowId);
  }

  /// Minimize window
  Future<void> minimizeWindow(String windowId) async {
    await windowManager.minimizeWindow(windowId);
  }

  /// Maximize window
  Future<void> maximizeWindow(String windowId) async {
    await windowManager.maximizeWindow(windowId);
  }

  /// Close window
  Future<void> closeWindow(String windowId) async {
    await windowManager.closeWindow(windowId);
  }

  /// Resize window
  Future<void> resizeWindow(String windowId, int width, int height) async {
    await windowManager.resizeWindow(windowId, width, height);
  }

  /// Move window
  Future<void> moveWindow(String windowId, int x, int y) async {
    await windowManager.moveWindow(windowId, x, y);
  }
}

// ==================== Data Models ====================

class CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get success => exitCode == 0;
}

class SystemInfo {
  final String operatingSystem;
  final String osVersion;
  final int numberOfProcessors;
  final String pathSeparator;
  final String localeName;

  SystemInfo({
    required this.operatingSystem,
    required this.osVersion,
    required this.numberOfProcessors,
    required this.pathSeparator,
    required this.localeName,
  });

  Map<String, dynamic> toJson() {
    return {
      'operating_system': operatingSystem,
      'os_version': osVersion,
      'number_of_processors': numberOfProcessors,
      'path_separator': pathSeparator,
      'locale_name': localeName,
    };
  }
}

class ProcessInfo {
  final int pid;
  final String name;
  final String? user;
  final double cpuUsage;
  final int memoryUsage;

  ProcessInfo({
    required this.pid,
    required this.name,
    this.user,
    this.cpuUsage = 0.0,
    this.memoryUsage = 0,
  });
}

