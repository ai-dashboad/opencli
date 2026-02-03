import 'dart:io';
import 'package:opencli_daemon/core/daemon.dart';
import 'package:opencli_daemon/core/config.dart';
import 'package:opencli_daemon/ui/terminal_ui.dart';

Future<void> main(List<String> arguments) async {
  // 打印启动横幅
  TerminalUI.printBanner('OpenCLI Daemon', 'v${Daemon.version}');

  TerminalUI.info('Initializing daemon...', prefix: '⚙');

  try {
    // Load configuration
    TerminalUI.progress('Loading configuration');
    final config = await Config.load();
    TerminalUI.progressDone();

    // Initialize daemon
    final daemon = Daemon(config);

    // Start daemon
    await daemon.start();

    TerminalUI.printDivider(width: 60);
    TerminalUI.success('Daemon started successfully', prefix: '🎉');
    TerminalUI.printKeyValue('Socket', config.socketPath);
    TerminalUI.printKeyValue('PID', pid.toString());
    TerminalUI.printDivider(width: 60);

    TerminalUI.printWelcome();

    // Handle shutdown signals
    ProcessSignal.sigterm.watch().listen((_) async {
      TerminalUI.printShutdown();
      await daemon.stop();
      exit(0);
    });

    ProcessSignal.sigint.watch().listen((_) async {
      TerminalUI.printShutdown();
      await daemon.stop();
      exit(0);
    });

    // Keep running
    await daemon.wait();

  } catch (e, stack) {
    TerminalUI.error('Fatal error: $e');
    print(TerminalUI.dim(stack.toString()));
    exit(1);
  }
}
