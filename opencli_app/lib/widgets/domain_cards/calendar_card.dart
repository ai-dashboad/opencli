import 'package:flutter/material.dart';

/// Calendar domain card — shows events, event creation confirmations.
class CalendarCard extends StatelessWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const CalendarCard({Key? key, required this.taskType, required this.result}) : super(key: key);

  static const _color = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success ? _color.withOpacity(0.06) : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: success ? _color.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForTask(), color: _color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_titleForTask(success),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: success ? _color : Colors.red[700]!)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!success)
            Text(result['error'] as String? ?? result['message'] as String? ?? 'Calendar action failed',
                style: TextStyle(color: Colors.red[700]))
          else if (taskType == 'calendar_list_events')
            _buildEventList()
          else
            _buildEventAction(),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final events = result['events'] as List<dynamic>? ?? [];
    final date = result['date'] as String? ?? 'today';
    final count = result['count'] as int? ?? events.length;

    if (count == 0) {
      return Text('No events $date', style: TextStyle(fontSize: 14, color: Colors.grey[500]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count event${count > 1 ? 's' : ''} $date',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 8),
        ...events.take(10).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.toString(), style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildEventAction() {
    final message = result['message'] as String? ?? '';
    final title = result['title'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(message, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ],
    );
  }

  IconData _iconForTask() {
    switch (taskType) {
      case 'calendar_add_event': return Icons.event;
      case 'calendar_list_events': return Icons.calendar_today;
      case 'calendar_delete_event': return Icons.event_busy;
      default: return Icons.calendar_today;
    }
  }

  String _titleForTask(bool success) {
    if (!success) return 'Calendar Error';
    switch (taskType) {
      case 'calendar_add_event': return 'Event Created';
      case 'calendar_list_events': return 'Calendar';
      case 'calendar_delete_event': return 'Event Deleted';
      default: return 'Calendar';
    }
  }
}
