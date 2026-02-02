import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:opencli_daemon/automation/types.dart';

/// Input automation controller - Mouse, keyboard, screen capture
class InputController {
  // ==================== Mouse Control ====================

  /// Click mouse at coordinates
  Future<void> clickMouse({required int x, required int y}) async {
    await moveMouse(x: x, y: y);
    await Future.delayed(Duration(milliseconds: 50));
    await _performClick();
  }

  /// Double click mouse
  Future<void> doubleClick({required int x, required int y}) async {
    await clickMouse(x: x, y: y);
    await Future.delayed(Duration(milliseconds: 100));
    await _performClick();
  }

  /// Right click mouse
  Future<void> rightClick({required int x, required int y}) async {
    await moveMouse(x: x, y: y);
    await Future.delayed(Duration(milliseconds: 50));
    await _performRightClick();
  }

  /// Move mouse to coordinates
  Future<void> moveMouse({required int x, required int y}) async {
    if (Platform.isMacOS) {
      await _macOSMoveMouse(x, y);
    } else if (Platform.isLinux) {
      await _linuxMoveMouse(x, y);
    } else if (Platform.isWindows) {
      await _windowsMoveMouse(x, y);
    }
  }

  /// Drag mouse from one point to another
  Future<void> dragMouse({
    required int fromX,
    required int fromY,
    required int toX,
    required int toY,
  }) async {
    await moveMouse(x: fromX, y: fromY);
    await _mouseDown();

    // Smooth drag motion
    final steps = 20;
    for (int i = 0; i <= steps; i++) {
      final x = fromX + ((toX - fromX) * i / steps).round();
      final y = fromY + ((toY - fromY) * i / steps).round();
      await moveMouse(x: x, y: y);
      await Future.delayed(Duration(milliseconds: 10));
    }

    await _mouseUp();
  }

  Future<void> _performClick() async {
    if (Platform.isMacOS) {
      await Process.run('cliclick', ['c:.']);
    } else if (Platform.isLinux) {
      await Process.run('xdotool', ['click', '1']);
    } else if (Platform.isWindows) {
      // Use Win32 API
    }
  }

  Future<void> _performRightClick() async {
    if (Platform.isMacOS) {
      await Process.run('cliclick', ['rc:.']);
    } else if (Platform.isLinux) {
      await Process.run('xdotool', ['click', '3']);
    }
  }

  Future<void> _mouseDown() async {
    if (Platform.isMacOS) {
      await Process.run('cliclick', ['dd:.']);
    } else if (Platform.isLinux) {
      await Process.run('xdotool', ['mousedown', '1']);
    }
  }

  Future<void> _mouseUp() async {
    if (Platform.isMacOS) {
      await Process.run('cliclick', ['du:.']);
    } else if (Platform.isLinux) {
      await Process.run('xdotool', ['mouseup', '1']);
    }
  }

  Future<void> _macOSMoveMouse(int x, int y) async {
    await Process.run('cliclick', ['m:$x,$y']);
  }

  Future<void> _linuxMoveMouse(int x, int y) async {
    await Process.run('xdotool', ['mousemove', x.toString(), y.toString()]);
  }

  Future<void> _windowsMoveMouse(int x, int y) async {
    // Implement using Win32 API
  }

  // ==================== Keyboard Control ====================

  /// Type text
  Future<void> typeText(String text, {
    Duration delayBetweenKeys = const Duration(milliseconds: 50),
  }) async {
    for (final char in text.split('')) {
      await _typeChar(char);
      await Future.delayed(delayBetweenKeys);
    }
  }

  /// Press key combination (e.g., ['cmd', 'c'])
  Future<void> pressKeys(List<String> keys) async {
    if (Platform.isMacOS) {
      final keyString = keys.join('+').toLowerCase();
      await Process.run('cliclick', ['kp:$keyString']);
    } else if (Platform.isLinux) {
      await Process.run('xdotool', ['key', keys.join('+')]);
    }
  }

  /// Press enter key
  Future<void> pressEnter() async {
    await pressKeys(['Return']);
  }

  /// Press tab key
  Future<void> pressTab() async {
    await pressKeys(['Tab']);
  }

  /// Press escape key
  Future<void> pressEscape() async {
    await pressKeys(['Escape']);
  }

  Future<void> _typeChar(String char) async {
    if (Platform.isMacOS) {
      await Process.run('cliclick', ['t:$char']);
    } else if (Platform.isLinux) {
      await Process.run('xdotool', ['type', char]);
    }
  }

  // ==================== Screen Capture ====================

  /// Capture screen
  Future<Screenshot> captureScreen({Rectangle? region}) async {
    if (Platform.isMacOS) {
      return await _macOSCaptureScreen(region);
    } else if (Platform.isLinux) {
      return await _linuxCaptureScreen(region);
    } else if (Platform.isWindows) {
      return await _windowsCaptureScreen(region);
    }

    throw UnsupportedError('Platform not supported');
  }

  Future<Screenshot> _macOSCaptureScreen(Rectangle? region) async {
    final tempFile = '/tmp/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';

    if (region != null) {
      await Process.run('screencapture', [
        '-R${region.x},${region.y},${region.width},${region.height}',
        tempFile,
      ]);
    } else {
      await Process.run('screencapture', [tempFile]);
    }

    final file = File(tempFile);
    final data = await file.readAsBytes();
    await file.delete();

    return Screenshot(
      data: data,
      width: region?.width ?? 1920, // Default, should get actual screen size
      height: region?.height ?? 1080,
    );
  }

  Future<Screenshot> _linuxCaptureScreen(Rectangle? region) async {
    final tempFile = '/tmp/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';

    if (region != null) {
      await Process.run('import', [
        '-window', 'root',
        '-crop', '${region.width}x${region.height}+${region.x}+${region.y}',
        tempFile,
      ]);
    } else {
      await Process.run('import', ['-window', 'root', tempFile]);
    }

    final file = File(tempFile);
    final data = await file.readAsBytes();
    await file.delete();

    return Screenshot(
      data: data,
      width: region?.width ?? 1920,
      height: region?.height ?? 1080,
    );
  }

  Future<Screenshot> _windowsCaptureScreen(Rectangle? region) async {
    // Implement using Win32 API
    throw UnimplementedError('Windows screenshot not yet implemented');
  }

  // ==================== OCR ====================

  /// Read text from screen using OCR
  Future<String> readTextFromScreen({Rectangle? region}) async {
    final screenshot = await captureScreen(region: region);

    // Save screenshot temporarily
    final tempFile = '/tmp/ocr_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(tempFile).writeAsBytes(screenshot.data);

    // Run Tesseract OCR
    final result = await Process.run('tesseract', [tempFile, 'stdout']);

    // Clean up
    await File(tempFile).delete();

    return result.stdout.toString().trim();
  }

  // ==================== Image Recognition ====================

  /// Find image template on screen
  Future<Point?> findImageOnScreen(String templatePath) async {
    final screenshot = await captureScreen();

    // Save screenshot temporarily
    final screenshotFile = '/tmp/screen_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(screenshotFile).writeAsBytes(screenshot.data);

    // Use ImageMagick or OpenCV for template matching
    // This is a placeholder - actual implementation would use computer vision library
    final result = await Process.run('python3', [
      '-c',
      '''
import cv2
import numpy as np

screen = cv2.imread("$screenshotFile")
template = cv2.imread("$templatePath")

result = cv2.matchTemplate(screen, template, cv2.TM_CCOEFF_NORMED)
min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(result)

if max_val > 0.8:
    print(f"{max_loc[0]},{max_loc[1]}")
else:
    print("NOT_FOUND")
'''
    ]);

    // Clean up
    await File(screenshotFile).delete();

    final output = result.stdout.toString().trim();
    if (output == 'NOT_FOUND') {
      return null;
    }

    final coords = output.split(',');
    return Point(int.parse(coords[0]), int.parse(coords[1]));
  }

  /// Wait for image to appear on screen
  Future<Point?> waitForImage(
    String templatePath, {
    Duration timeout = const Duration(seconds: 30),
    Duration checkInterval = const Duration(seconds: 1),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final point = await findImageOnScreen(templatePath);
      if (point != null) {
        return point;
      }
      await Future.delayed(checkInterval);
    }

    return null;
  }
}

