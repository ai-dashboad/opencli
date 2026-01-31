import 'dart:io';
import 'package:opencli_daemon/core/daemon.dart';
import 'package:opencli_daemon/core/config.dart';

Future<void> main(List<String> arguments) async {
  print('OpenCLI Daemon v0.1.0');
  print('Starting daemon...');

  try {
    // Load configuration
    final config = await Config.load();

    // Initialize daemon
    final daemon = Daemon(config);

    // Start daemon
    await daemon.start();

    print('✓ Daemon started successfully');
    print('  Socket: ${config.socketPath}');
    print('  PID: ${pid}');

    // Handle shutdown signals
    ProcessSignal.sigterm.watch().listen((_) async {
      print('\nReceived SIGTERM, shutting down...');
      await daemon.stop();
      exit(0);
    });

    ProcessSignal.sigint.watch().listen((_) async {
      print('\nReceived SIGINT, shutting down...');
      await daemon.stop();
      exit(0);
    });

    // Keep running
    await daemon.wait();

  } catch (e, stack) {
    print('Fatal error: $e');
    print(stack);
    exit(1);
  }
}
