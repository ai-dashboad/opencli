import 'dart:io';

/// Process management - List, start, stop, monitor processes
class ProcessManager {
  /// List all running processes
  Future<List<ProcessInfo>> listProcesses() async {
    final processes = <ProcessInfo>[];

    if (Platform.isMacOS || Platform.isLinux) {
      final result = await Process.run('ps', ['-eo', 'pid,comm,%cpu,%mem,user']);
      final lines = result.stdout.toString().split('\n').skip(1); // Skip header

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 5) {
          processes.add(ProcessInfo(
            pid: int.tryParse(parts[0]) ?? 0,
            name: parts[1],
            cpuUsage: double.tryParse(parts[2]) ?? 0.0,
            memoryUsage: double.tryParse(parts[3]) ?? 0.0,
            user: parts[4],
          ));
        }
      }
    } else if (Platform.isWindows) {
      // Use tasklist command
      final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
      final lines = result.stdout.toString().split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split(',').map((s) => s.replaceAll('"', '')).toList();
        if (parts.length >= 2) {
          processes.add(ProcessInfo(
            pid: int.tryParse(parts[1]) ?? 0,
            name: parts[0],
          ));
        }
      }
    }

    return processes;
  }

  /// Get process by PID
  Future<ProcessInfo?> getProcess(int pid) async {
    final processes = await listProcesses();
    return processes.firstWhere(
      (p) => p.pid == pid,
      orElse: () => ProcessInfo(pid: 0, name: ''),
    );
  }

  /// Find processes by name
  Future<List<ProcessInfo>> findProcessesByName(String name) async {
    final processes = await listProcesses();
    return processes.where((p) =>
      p.name.toLowerCase().contains(name.toLowerCase())
    ).toList();
  }

  /// Kill process by PID
  Future<void> killProcess(int pid) async {
    if (Platform.isMacOS || Platform.isLinux) {
      await Process.run('kill', ['-9', pid.toString()]);
    } else if (Platform.isWindows) {
      await Process.run('taskkill', ['/PID', pid.toString(), '/F']);
    }
  }

  /// Kill processes by name
  Future<void> killProcessesByName(String name) async {
    if (Platform.isMacOS || Platform.isLinux) {
      await Process.run('pkill', [name]);
    } else if (Platform.isWindows) {
      await Process.run('taskkill', ['/IM', '$name.exe', '/F']);
    }
  }

  /// Start process
  Future<Process> startProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    return await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }

  /// Check if process is running
  Future<bool> isProcessRunning(int pid) async {
    final process = await getProcess(pid);
    return process != null && process.pid != 0;
  }

  /// Get process CPU usage
  Future<double> getProcessCpuUsage(int pid) async {
    final process = await getProcess(pid);
    return process?.cpuUsage ?? 0.0;
  }

  /// Get process memory usage
  Future<double> getProcessMemoryUsage(int pid) async {
    final process = await getProcess(pid);
    return process?.memoryUsage ?? 0.0;
  }

  /// Monitor process (stream of updates)
  Stream<ProcessInfo> monitorProcess(int pid, {
    Duration interval = const Duration(seconds: 1),
  }) async* {
    while (true) {
      final process = await getProcess(pid);
      if (process != null && process.pid != 0) {
        yield process;
      } else {
        break; // Process died
      }
      await Future.delayed(interval);
    }
  }
}

class ProcessInfo {
  final int pid;
  final String name;
  final double cpuUsage;
  final double memoryUsage;
  final String? user;

  ProcessInfo({
    required this.pid,
    required this.name,
    this.cpuUsage = 0.0,
    this.memoryUsage = 0.0,
    this.user,
  });

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'name': name,
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'user': user,
    };
  }

  @override
  String toString() {
    return 'ProcessInfo(pid: $pid, name: $name, cpu: ${cpuUsage.toStringAsFixed(1)}%, mem: ${memoryUsage.toStringAsFixed(1)}%)';
  }
}
