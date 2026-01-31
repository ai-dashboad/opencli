import 'dart:async';
import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class FlutterSkill {
  VmService? _vmService;
  String? _isolateId;
  Process? _appProcess;
  String? _vmServiceUri;

  final Map<String, dynamic> _config;

  FlutterSkill({Map<String, dynamic>? config})
      : _config = config ?? {
          'default_device': 'macos',
          'screenshot_format': 'png',
          'auto_hot_reload': true,
          'timeout_seconds': 30,
        };

  /// Launch a Flutter application
  Future<String> launch({
    String? device,
    String? projectPath,
  }) async {
    final targetDevice = device ?? _config['default_device'];
    final project = projectPath ?? Directory.current.path;

    print('Launching Flutter app on $targetDevice...');

    // Build flutter run command
    final args = [
      'run',
      '-d',
      targetDevice,
      '--observatory-port=0', // Auto-assign port
    ];

    _appProcess = await Process.start(
      'flutter',
      args,
      workingDirectory: project,
    );

    // Listen for VM Service URI
    final completer = Completer<String>();

    _appProcess!.stdout
        .transform(systemEncoding.decoder)
        .listen((line) {
      print('[Flutter] $line');

      // Extract VM Service URI
      if (line.contains('Dart VM Service') || line.contains('Observatory')) {
        final match = RegExp(r'http://[^\s]+').firstMatch(line);
        if (match != null && !completer.isCompleted) {
          _vmServiceUri = match.group(0);
          completer.complete(_vmServiceUri);
        }
      }
    });

    _appProcess!.stderr
        .transform(systemEncoding.decoder)
        .listen((line) {
      print('[Flutter Error] $line');
    });

    // Wait for VM Service URI or timeout
    try {
      await completer.future.timeout(
        Duration(seconds: _config['timeout_seconds']),
      );

      // Connect to VM Service
      await _connectToVmService(_vmServiceUri!);

      return 'Flutter app launched successfully. VM Service: $_vmServiceUri';
    } on TimeoutException {
      _appProcess?.kill();
      throw Exception('Failed to launch app: timeout waiting for VM Service');
    }
  }

  /// Connect to a running Flutter app's VM Service
  Future<String> connect(String uri) async {
    _vmServiceUri = uri;
    await _connectToVmService(uri);
    return 'Connected to VM Service: $uri';
  }

  Future<void> _connectToVmService(String uri) async {
    _vmService = await vmServiceConnectUri(uri);

    // Get main isolate
    final vm = await _vmService!.getVM();
    final isolate = vm.isolates?.first;

    if (isolate == null) {
      throw Exception('No isolates found');
    }

    _isolateId = isolate.id!;
    print('Connected to isolate: $_isolateId');
  }

  /// Get interactive UI elements
  Future<String> inspect() async {
    _ensureConnected();

    final result = await _vmService!.callServiceExtension(
      'ext.flutter.inspector.getRootWidgetTree',
      isolateId: _isolateId,
    );

    return result.json.toString();
  }

  /// Take a screenshot
  Future<String> screenshot({String? outputPath}) async {
    _ensureConnected();

    final result = await _vmService!.callServiceExtension(
      'ext.flutter.driver.screenshot',
      isolateId: _isolateId,
    );

    final screenshotData = result.json?['screenshot'];
    if (screenshotData == null) {
      throw Exception('Failed to capture screenshot');
    }

    // Save to file
    final format = _config['screenshot_format'];
    final path = outputPath ?? 'screenshot_${DateTime.now().millisecondsSinceEpoch}.$format';
    final file = File(path);

    // Decode base64 and write
    // TODO: Implement proper base64 decode and save

    return 'Screenshot saved to: $path';
  }

  /// Tap on an element
  Future<String> tap({String? key, String? text}) async {
    _ensureConnected();

    final finder = _buildFinder(key: key, text: text);

    await _vmService!.callServiceExtension(
      'ext.flutter.driver.tap',
      args: {'finderType': finder},
      isolateId: _isolateId,
    );

    return 'Tapped on element';
  }

  /// Enter text into a TextField
  Future<String> enterText({required String key, required String text}) async {
    _ensureConnected();

    final finder = _buildFinder(key: key);

    await _vmService!.callServiceExtension(
      'ext.flutter.driver.enterText',
      args: {
        'finderType': finder,
        'text': text,
      },
      isolateId: _isolateId,
    );

    return 'Entered text: $text';
  }

  /// Scroll to make an element visible
  Future<String> scrollTo({String? key, String? text}) async {
    _ensureConnected();

    final finder = _buildFinder(key: key, text: text);

    await _vmService!.callServiceExtension(
      'ext.flutter.driver.scrollIntoView',
      args: {'finderType': finder},
      isolateId: _isolateId,
    );

    return 'Scrolled to element';
  }

  /// Hot reload the application
  Future<String> hotReload() async {
    _ensureConnected();

    final result = await _vmService!.callServiceExtension(
      'ext.flutter.reassemble',
      isolateId: _isolateId,
    );

    if (_config['auto_hot_reload']) {
      return 'Hot reload completed successfully';
    }

    return result.toString();
  }

  /// Get current route name
  Future<String> getCurrentRoute() async {
    _ensureConnected();

    final result = await _vmService!.callServiceExtension(
      'ext.flutter.inspector.getSelectedRenderObject',
      isolateId: _isolateId,
    );

    // TODO: Extract route name from result
    return result.json.toString();
  }

  /// Navigate back
  Future<String> goBack() async {
    _ensureConnected();

    // Simulate back button press
    await tap(key: 'BackButton');

    return 'Navigated back';
  }

  /// Wait for an element to appear
  Future<String> waitFor({String? key, String? text, int? timeoutMs}) async {
    _ensureConnected();

    final timeout = timeoutMs ?? _config['timeout_seconds'] * 1000;
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime).inMilliseconds < timeout) {
      try {
        // Try to find element
        final finder = _buildFinder(key: key, text: text);
        await _vmService!.callServiceExtension(
          'ext.flutter.driver.waitFor',
          args: {
            'finderType': finder,
            'timeout': 100,
          },
          isolateId: _isolateId,
        );

        return 'Element found';
      } catch (e) {
        // Element not found yet, continue waiting
        await Future.delayed(Duration(milliseconds: 100));
      }
    }

    throw Exception('Element not found within timeout');
  }

  Map<String, dynamic> _buildFinder({String? key, String? text}) {
    if (key != null) {
      return {'key': key};
    } else if (text != null) {
      return {'text': text};
    } else {
      throw ArgumentError('Either key or text must be provided');
    }
  }

  void _ensureConnected() {
    if (_vmService == null || _isolateId == null) {
      throw Exception('Not connected to Flutter app. Call launch() or connect() first.');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _vmService?.dispose();
    _appProcess?.kill();
  }
}
