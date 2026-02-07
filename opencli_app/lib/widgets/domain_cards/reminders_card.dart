import 'package:flutter/material.dart';

/// Reminders domain card — shows reminder lists, add/complete confirmations.
class RemindersCard extends StatelessWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const RemindersCard({Key? key, required this.taskType, required this.result}) : super(key: key);

  static const _color = Color(0xFFFF9800);

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
            Text(result['error'] as String? ?? result['message'] as String? ?? 'Reminders action failed',
                style: TextStyle(color: Colors.red[700]))
          else if (taskType == 'reminders_list')
            _buildReminderList()
          else
            _buildReminderAction(),
        ],
      ),
    );
  }

  Widget _buildReminderList() {
    final reminders = result['reminders'] as List<dynamic>? ?? [];
    final count = result['count'] as int? ?? reminders.length;

    if (count == 0) {
      return const Text('No reminders', style: TextStyle(fontSize: 14, color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count reminder${count > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 8),
        ...reminders.take(15).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.radio_button_unchecked, size: 18, color: _color.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.toString(), style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildReminderAction() {
    final message = result['message'] as String? ?? '';
    final task = result['task'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.isNotEmpty)
          Text(task, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(message, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ],
    );
  }

  IconData _iconForTask() {
    switch (taskType) {
      case 'reminders_add': return Icons.add_task;
      case 'reminders_list': return Icons.checklist;
      case 'reminders_complete': return Icons.task_alt;
      default: return Icons.checklist;
    }
  }

  String _titleForTask(bool success) {
    if (!success) return 'Reminders Error';
    switch (taskType) {
      case 'reminders_add': return 'Reminder Added';
      case 'reminders_list': return 'Reminders';
      case 'reminders_complete': return 'Reminder Completed';
      default: return 'Reminders';
    }
  }
}
