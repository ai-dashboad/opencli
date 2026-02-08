import 'dart:async';
import 'dart:io';
import 'package:opencli_daemon/core/daemon.dart';

class HealthMonitor {
  final Daemon daemon;
  final Duration checkInterval;

  Timer? _timer;
  final DateTime _startTime = DateTime.now();

  HealthMonitor({
    required this.daemon,
    required this.checkInterval,
  });

  int get uptimeSeconds => DateTime.now().difference(_startTime).inSeconds;

  double get memoryUsageMb {
    // Approximate memory usage
    return ProcessInfo.currentRss / 1024 / 1024;
  }

  void start() {
    _timer = Timer.periodic(checkInterval, (_) => _performHealthCheck());
    print('Health monitor started');
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  void _performHealthCheck() {
    final stats = daemon.getStats();

    // Log stats periodically
    if (uptimeSeconds % 300 == 0) {
      // Every 5 minutes
      print(
          'Health check - Uptime: ${uptimeSeconds}s, Memory: ${memoryUsageMb.toStringAsFixed(1)}MB');
    }

    // Check memory limits
    if (memoryUsageMb > 200) {
      print(
          'WARNING: Memory usage high: ${memoryUsageMb.toStringAsFixed(1)}MB');
    }
  }
}
