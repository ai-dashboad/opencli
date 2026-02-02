import 'dart:io';
import 'dart:async';

/// Launches the Web UI development server
class WebUILauncher {
  Process? _webUiProcess;
  final String projectRoot;
  final int port;
  bool _isRunning = false;

  WebUILauncher({
    required this.projectRoot,
    this.port = 3000,
  });

  bool get isRunning => _isRunning;

  /// Start the Web UI server
  Future<void> start() async {
    if (_isRunning) {
      print('⚠️  Web UI already running');
      return;
    }

    try {
      final webUiDir = '$projectRoot/web-ui';
      final webUiPath = Directory(webUiDir);

      if (!await webUiPath.exists()) {
        print('⚠️  Web UI directory not found: $webUiDir');
        return;
      }

      // Check if node_modules exists
      final nodeModules = Directory('$webUiDir/node_modules');
      if (!await nodeModules.exists()) {
        print('📦 Installing Web UI dependencies...');
        final installResult = await Process.run(
          'npm',
          ['install'],
          workingDirectory: webUiDir,
        );

        if (installResult.exitCode != 0) {
          print('❌ Failed to install Web UI dependencies');
          print(installResult.stderr);
          return;
        }
        print('✓ Web UI dependencies installed');
      }

      // Start the dev server
      print('🚀 Starting Web UI server...');
      _webUiProcess = await Process.start(
        'npm',
        ['run', 'dev', '--', '--port', port.toString(), '--host'],
        workingDirectory: webUiDir,
        mode: ProcessStartMode.detached,
      );

      // Listen for output to confirm startup
      _webUiProcess!.stdout.listen((data) {
        final output = String.fromCharCodes(data);
        if (output.contains('Local:') || output.contains('http://')) {
          if (!_isRunning) {
            _isRunning = true;
            print('✓ Web UI started at http://localhost:$port');
            print('  Open in browser: http://localhost:$port');
          }
        }
      });

      _webUiProcess!.stderr.listen((data) {
        final error = String.fromCharCodes(data);
        // Only print actual errors, not warnings
        if (error.contains('ERROR') || error.contains('EADDRINUSE')) {
          print('⚠️  Web UI: $error');
        }
      });

      // Give it a moment to start
      await Future.delayed(const Duration(seconds: 2));

      if (_webUiProcess == null || _webUiProcess!.pid == 0) {
        print('❌ Failed to start Web UI');
        _isRunning = false;
        return;
      }

      // Try to open in browser
      if (Platform.isMacOS) {
        await _openInBrowser();
      }
    } catch (e) {
      print('❌ Error starting Web UI: $e');
      _isRunning = false;
    }
  }

  /// Open Web UI in default browser
  Future<void> _openInBrowser() async {
    try {
      await Process.run('open', ['http://localhost:$port']);
      print('🌐 Web UI opened in browser');
    } catch (e) {
      print('⚠️  Could not open browser: $e');
    }
  }

  /// Stop the Web UI server
  Future<void> stop() async {
    if (_webUiProcess != null) {
      print('Stopping Web UI...');
      _webUiProcess!.kill(ProcessSignal.sigterm);
      _webUiProcess = null;
      _isRunning = false;
      print('✓ Web UI stopped');
    }
  }
}
