import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:opencli_mobile/models/daemon_status.dart';

class DaemonStatusCard extends StatefulWidget {
  final String statusUrl;

  const DaemonStatusCard({
    Key? key,
    this.statusUrl = 'http://localhost:9875/status',
  }) : super(key: key);

  @override
  State<DaemonStatusCard> createState() => _DaemonStatusCardState();
}

class _DaemonStatusCardState extends State<DaemonStatusCard> {
  DaemonStatus? _status;
  Timer? _updateTimer;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _updateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchStatus();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final response = await http.get(Uri.parse(widget.statusUrl));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _status = DaemonStatus.fromJson(json);
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Status code: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null && _status == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Daemon Offline',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Unable to connect to daemon status server',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final status = _status!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 12),
                const SizedBox(width: 8),
                Text(
                  'Daemon Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  status.daemon.version,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  icon: Icons.timer,
                  label: 'Uptime',
                  value: status.daemon.formattedUptime,
                ),
                _buildStatItem(
                  icon: Icons.memory,
                  label: 'Memory',
                  value: '${status.daemon.memoryMb.toStringAsFixed(1)}MB',
                ),
                _buildStatItem(
                  icon: Icons.extension,
                  label: 'Plugins',
                  value: '${status.daemon.pluginsLoaded}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  icon: Icons.phone_android,
                  label: 'Clients',
                  value: '${status.mobile.connectedClients}',
                ),
                _buildStatItem(
                  icon: Icons.api,
                  label: 'Requests',
                  value: '${status.daemon.totalRequests}',
                ),
                const SizedBox(width: 80), // Spacer for alignment
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
