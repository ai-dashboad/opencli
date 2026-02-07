import 'package:flutter/material.dart';

/// Timer domain card — shows timer status, countdown info.
class TimerCard extends StatelessWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const TimerCard({Key? key, required this.taskType, required this.result}) : super(key: key);

  static const _color = Color(0xFF009688);

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success ? _color.withOpacity(0.08) : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: success ? _color.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForTask(), color: _color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _titleForTask(success),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: success ? _color : Colors.red[700]!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!success)
            Text(result['error'] as String? ?? result['message'] as String? ?? 'Timer action failed',
                style: TextStyle(color: Colors.red[700]))
          else if (taskType == 'timer_status')
            _buildTimerStatus()
          else
            _buildTimerInfo(),
        ],
      ),
    );
  }

  Widget _buildTimerInfo() {
    final widgets = <Widget>[];

    if (result['message'] != null) {
      widgets.add(Text(result['message'] as String, style: const TextStyle(fontSize: 14)));
    }
    if (result['label'] != null) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(Text('Label: ${result['label']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])));
    }
    if (result['minutes'] != null) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(Text('Duration: ${result['minutes']} minutes',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildTimerStatus() {
    final active = result['active_timers'] as int? ?? 0;
    if (active == 0) {
      return const Text('No active timers', style: TextStyle(fontSize: 14, color: Colors.grey));
    }

    final timers = result['timers'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$active active timer${active > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...timers.map((t) {
          final timer = t as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.timer, size: 16, color: _color),
                const SizedBox(width: 8),
                Text(timer['label'] as String? ?? 'Timer',
                    style: const TextStyle(fontSize: 13)),
                const Spacer(),
                Text('${timer['remaining_seconds']}s left',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          );
        }),
      ],
    );
  }

  IconData _iconForTask() {
    switch (taskType) {
      case 'timer_set': return Icons.timer;
      case 'timer_cancel': return Icons.timer_off;
      case 'timer_status': return Icons.timelapse;
      case 'timer_pomodoro': return Icons.self_improvement;
      default: return Icons.timer;
    }
  }

  String _titleForTask(bool success) {
    if (!success) return 'Timer Error';
    switch (taskType) {
      case 'timer_set': return 'Timer Set';
      case 'timer_cancel': return 'Timer Cancelled';
      case 'timer_status': return 'Timer Status';
      case 'timer_pomodoro': return 'Pomodoro Started';
      default: return 'Timer';
    }
  }
}
