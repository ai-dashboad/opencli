class DaemonStatus {
  final DaemonInfo daemon;
  final MobileInfo mobile;
  final DateTime timestamp;

  DaemonStatus({
    required this.daemon,
    required this.mobile,
    required this.timestamp,
  });

  factory DaemonStatus.fromJson(Map<String, dynamic> json) {
    return DaemonStatus(
      daemon: DaemonInfo.fromJson(json['daemon'] as Map<String, dynamic>),
      mobile: MobileInfo.fromJson(json['mobile'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class DaemonInfo {
  final String version;
  final int uptimeSeconds;
  final double memoryMb;
  final int pluginsLoaded;
  final int totalRequests;

  DaemonInfo({
    required this.version,
    required this.uptimeSeconds,
    required this.memoryMb,
    required this.pluginsLoaded,
    required this.totalRequests,
  });

  factory DaemonInfo.fromJson(Map<String, dynamic> json) {
    return DaemonInfo(
      version: json['version'] as String,
      uptimeSeconds: json['uptime_seconds'] as int,
      memoryMb: (json['memory_mb'] as num).toDouble(),
      pluginsLoaded: json['plugins_loaded'] as int,
      totalRequests: json['total_requests'] as int,
    );
  }

  String get formattedUptime {
    if (uptimeSeconds < 60) {
      return '${uptimeSeconds}s';
    } else if (uptimeSeconds < 3600) {
      return '${uptimeSeconds ~/ 60}m ${uptimeSeconds % 60}s';
    } else {
      final hours = uptimeSeconds ~/ 3600;
      final minutes = (uptimeSeconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }
}

class MobileInfo {
  final int connectedClients;
  final List<String> clientIds;

  MobileInfo({
    required this.connectedClients,
    required this.clientIds,
  });

  factory MobileInfo.fromJson(Map<String, dynamic> json) {
    return MobileInfo(
      connectedClients: json['connected_clients'] as int,
      clientIds: (json['client_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}
