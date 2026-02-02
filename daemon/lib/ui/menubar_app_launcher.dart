import 'dart:io';

/// Launches a simple macOS menubar application
class MenubarAppLauncher {
  final String statusUrl;
  bool _isRunning = false;

  MenubarAppLauncher({
    this.statusUrl = 'http://localhost:9875/status',
  });

  bool get isRunning => _isRunning;

  /// Start the menubar app
  Future<void> start() async {
    if (!Platform.isMacOS) {
      print('⚠️  Menubar app only available on macOS');
      return;
    }

    if (_isRunning) {
      print('⚠️  Menubar app already running');
      return;
    }

    try {
      // Try to launch native menubar app
      final projectRoot = _findProjectRoot();
      if (projectRoot != null) {
        final menubarApp = '$projectRoot/menubar-app/OpenCLI.app';
        final menubarAppDir = Directory(menubarApp);

        if (await menubarAppDir.exists()) {
          await Process.start(
            'open',
            [menubarApp],
            mode: ProcessStartMode.detached,
          );
          _isRunning = true;
          print('✓ Native menubar app started');
          return;
        }
      }

      // Fallback to AppleScript if native app not found
      final script = _createMenubarScript();
      final tempScript = File('/tmp/opencli_menubar.scpt');
      await tempScript.writeAsString(script);

      await Process.start(
        'osascript',
        [tempScript.path],
        mode: ProcessStartMode.detached,
      );

      _isRunning = true;
      print('✓ Menubar app started (AppleScript fallback)');
    } catch (e) {
      print('⚠️  Could not start menubar app: $e');
    }
  }

  String? _findProjectRoot() {
    try {
      var dir = Directory.current;
      for (var i = 0; i < 5; i++) {
        final menubarDir = Directory('${dir.path}/menubar-app');
        if (menubarDir.existsSync()) {
          return dir.path;
        }
        dir = dir.parent;
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  String _createMenubarScript() {
    return '''
on run
    set statusURL to "$statusUrl"

    repeat
        try
            set statusJSON to do shell script "curl -s " & quoted form of statusURL

            -- Show notification with status
            display notification statusJSON with title "OpenCLI Daemon" subtitle "Status Update"
        end try

        -- Check every 30 seconds
        delay 30
    end repeat
end run
''';
  }

  Future<void> stop() async {
    if (_isRunning) {
      // Kill osascript processes
      await Process.run('pkill', ['-f', 'opencli_menubar.scpt']);
      _isRunning = false;
      print('✓ Menubar app stopped');
    }
  }
}
