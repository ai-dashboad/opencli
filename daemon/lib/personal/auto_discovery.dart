/// Auto-discovery service using mDNS/Bonjour for personal mode
///
/// Enables automatic device discovery on local network without manual configuration.
/// Mobile devices can find the OpenCLI daemon automatically when on the same WiFi.
library;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

/// mDNS service for auto-discovery
class AutoDiscoveryService {
  final String serviceName;
  final int port;
  final Map<String, String> metadata;

  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  bool _isRunning = false;

  // mDNS constants
  static const String multicastAddress = '224.0.0.251';
  static const int multicastPort = 5353;
  static const String serviceType = '_opencli._tcp.local';

  AutoDiscoveryService({
    required this.serviceName,
    required this.port,
    Map<String, String>? metadata,
  }) : metadata = metadata ?? {};

  /// Start the mDNS service
  Future<void> start() async {
    if (_isRunning) return;

    try {
      // Bind to multicast port
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        multicastPort,
      );

      // Join multicast group
      _socket!.joinMulticast(InternetAddress(multicastAddress));

      // Enable broadcast
      _socket!.broadcastEnabled = true;

      // Listen for discovery requests
      _socket!.listen(_handleMessage);

      // Send periodic announcements every 30 seconds
      _announceTimer = Timer.periodic(
        Duration(seconds: 30),
        (_) => _announceService(),
      );

      // Send initial announcement
      _announceService();

      _isRunning = true;
      print('[AutoDiscovery] Service started: $serviceName on port $port');
    } catch (e) {
      print('[AutoDiscovery] Failed to start: $e');
      rethrow;
    }
  }

  /// Stop the mDNS service
  Future<void> stop() async {
    if (!_isRunning) return;

    // Send goodbye message
    _sendGoodbye();

    // Cancel timer
    _announceTimer?.cancel();
    _announceTimer = null;

    // Close socket
    _socket?.close();
    _socket = null;

    _isRunning = false;
    print('[AutoDiscovery] Service stopped');
  }

  /// Handle incoming mDNS messages
  void _handleMessage(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    try {
      final message = String.fromCharCodes(datagram.data);

      // Check if it's a discovery query
      if (_isDiscoveryQuery(message)) {
        print('[AutoDiscovery] Received discovery query from ${datagram.address}');
        _respondToQuery(datagram.address, datagram.port);
      }
    } catch (e) {
      // Ignore malformed messages
    }
  }

  /// Check if message is a discovery query
  bool _isDiscoveryQuery(String message) {
    return message.contains(serviceType) ||
           message.contains('_services._dns-sd._udp.local');
  }

  /// Respond to discovery query
  void _respondToQuery(InternetAddress address, int port) {
    final response = _buildServiceAnnouncement();
    _sendMessage(response, address, port);
  }

  /// Send periodic service announcement
  void _announceService() {
    final announcement = _buildServiceAnnouncement();
    _sendMessage(
      announcement,
      InternetAddress(multicastAddress),
      multicastPort,
    );
  }

  /// Build service announcement message
  Map<String, dynamic> _buildServiceAnnouncement() {
    return {
      'type': 'service_announcement',
      'service': serviceType,
      'name': serviceName,
      'port': port,
      'hostname': Platform.localHostname,
      'addresses': _getLocalAddresses(),
      'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Send goodbye message when stopping
  void _sendGoodbye() {
    final goodbye = {
      'type': 'goodbye',
      'service': serviceType,
      'name': serviceName,
    };
    _sendMessage(
      goodbye,
      InternetAddress(multicastAddress),
      multicastPort,
    );
  }

  /// Send message to specific address
  void _sendMessage(Map<String, dynamic> message, InternetAddress address, int port) {
    try {
      final data = utf8.encode(jsonEncode(message));
      _socket?.send(data, address, port);
    } catch (e) {
      print('[AutoDiscovery] Failed to send message: $e');
    }
  }

  /// Get local IP addresses
  List<String> _getLocalAddresses() {
    final addresses = <String>[];
    try {
      NetworkInterface.list().then((interfaces) {
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              addresses.add(addr.address);
            }
          }
        }
      });
    } catch (e) {
      print('[AutoDiscovery] Failed to get local addresses: $e');
    }
    return addresses;
  }

  /// Update service metadata
  void updateMetadata(Map<String, String> newMetadata) {
    metadata.addAll(newMetadata);
    if (_isRunning) {
      _announceService();
    }
  }

  bool get isRunning => _isRunning;
}

/// Discovery client for finding OpenCLI services
class DiscoveryClient {
  RawDatagramSocket? _socket;
  final _discoveries = <String, ServiceInfo>{};
  final _streamController = StreamController<ServiceInfo>.broadcast();

  /// Stream of discovered services
  Stream<ServiceInfo> get discoveries => _streamController.stream;

  /// Start scanning for services
  Future<void> startScanning() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AutoDiscoveryService.multicastPort,
      );

      _socket!.joinMulticast(InternetAddress(AutoDiscoveryService.multicastAddress));
      _socket!.broadcastEnabled = true;
      _socket!.listen(_handleResponse);

      // Send discovery query
      _sendQuery();

      print('[DiscoveryClient] Started scanning for services');
    } catch (e) {
      print('[DiscoveryClient] Failed to start scanning: $e');
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    _socket?.close();
    _socket = null;
    await _streamController.close();
  }

  /// Send discovery query
  void _sendQuery() {
    final query = {
      'type': 'query',
      'service': AutoDiscoveryService.serviceType,
    };

    final data = utf8.encode(jsonEncode(query));
    _socket?.send(
      data,
      InternetAddress(AutoDiscoveryService.multicastAddress),
      AutoDiscoveryService.multicastPort,
    );
  }

  /// Handle discovery responses
  void _handleResponse(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    try {
      final message = String.fromCharCodes(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;

      if (json['type'] == 'service_announcement') {
        final service = ServiceInfo.fromJson(json);

        // Check if this is a new or updated service
        if (!_discoveries.containsKey(service.name) ||
            _discoveries[service.name]!.timestamp.isBefore(service.timestamp)) {
          _discoveries[service.name] = service;
          _streamController.add(service);
          print('[DiscoveryClient] Discovered service: ${service.name}');
        }
      } else if (json['type'] == 'goodbye') {
        final name = json['name'] as String;
        _discoveries.remove(name);
        print('[DiscoveryClient] Service left: $name');
      }
    } catch (e) {
      // Ignore malformed messages
    }
  }

  /// Get all discovered services
  List<ServiceInfo> getDiscoveredServices() {
    return _discoveries.values.toList();
  }
}

/// Information about a discovered service
class ServiceInfo {
  final String name;
  final String service;
  final int port;
  final String hostname;
  final List<String> addresses;
  final Map<String, String> metadata;
  final DateTime timestamp;

  ServiceInfo({
    required this.name,
    required this.service,
    required this.port,
    required this.hostname,
    required this.addresses,
    required this.metadata,
    required this.timestamp,
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> json) {
    return ServiceInfo(
      name: json['name'] as String,
      service: json['service'] as String,
      port: json['port'] as int,
      hostname: json['hostname'] as String,
      addresses: (json['addresses'] as List<dynamic>).cast<String>(),
      metadata: (json['metadata'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'service': service,
      'port': port,
      'hostname': hostname,
      'addresses': addresses,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Get connection URL
  String getConnectionUrl() {
    if (addresses.isEmpty) return '';
    return 'ws://${addresses.first}:$port';
  }
}
