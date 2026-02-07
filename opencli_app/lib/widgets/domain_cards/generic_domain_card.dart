import 'package:flutter/material.dart';

/// Generic fallback card for domains without a custom card widget.
/// Displays results as key-value pairs with domain-themed styling.
class GenericDomainCard extends StatelessWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const GenericDomainCard({
    Key? key,
    required this.taskType,
    required this.result,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;
    final domain = result['domain'] as String? ?? _inferDomain(taskType);
    final color = _domainColor(domain);
    final icon = _domainIcon(domain);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success ? color.withOpacity(0.08) : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: success ? color.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatTitle(taskType),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              if (success)
                Icon(Icons.check_circle, color: Colors.green[400], size: 20),
            ],
          ),
          const SizedBox(height: 12),
          if (!success && (result['error'] != null || result['message'] != null))
            Text(result['error'] as String? ?? result['message'] as String? ?? 'Action failed',
                style: TextStyle(color: Colors.red[700]))
          else if (success && result['message'] != null)
            Text(result['message'] as String, style: const TextStyle(fontSize: 14))
          else
            ..._buildKeyValuePairs(),
        ],
      ),
    );
  }

  List<Widget> _buildKeyValuePairs() {
    final skip = {'success', 'domain', 'card_type', 'exit_code', 'stderr'};
    return result.entries
        .where((e) => !skip.contains(e.key) && e.value != null && e.value.toString().isNotEmpty)
        .take(8)
        .map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      e.key.replaceAll('_', ' '),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value.toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  String _inferDomain(String taskType) {
    final parts = taskType.split('_');
    return parts.isNotEmpty ? parts[0] : 'unknown';
  }

  String _formatTitle(String taskType) {
    return taskType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Color _domainColor(String domain) {
    const colors = {
      'music': Color(0xFFE91E63),
      'timer': Color(0xFF009688),
      'calculator': Color(0xFF3F51B5),
      'calendar': Color(0xFF2196F3),
      'reminders': Color(0xFFFF9800),
      'notes': Color(0xFFFFC107),
      'weather': Color(0xFF03A9F4),
      'email': Color(0xFFF44336),
      'contacts': Color(0xFF4CAF50),
      'messages': Color(0xFF4CAF50),
      'translation': Color(0xFF673AB7),
      'files': Color(0xFF795548),
    };
    return colors[domain] ?? Colors.blueGrey;
  }

  IconData _domainIcon(String domain) {
    const icons = {
      'music': Icons.music_note,
      'timer': Icons.timer,
      'calculator': Icons.calculate,
      'calendar': Icons.calendar_today,
      'reminders': Icons.checklist,
      'notes': Icons.note,
      'weather': Icons.cloud,
      'email': Icons.email,
      'contacts': Icons.contacts,
      'messages': Icons.message,
      'translation': Icons.translate,
      'files': Icons.folder,
    };
    return icons[domain] ?? Icons.extension;
  }
}
