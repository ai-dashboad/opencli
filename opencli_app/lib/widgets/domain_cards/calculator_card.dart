import 'package:flutter/material.dart';

/// Calculator domain card — shows expression = result cleanly.
class CalculatorCard extends StatelessWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const CalculatorCard({Key? key, required this.taskType, required this.result}) : super(key: key);

  static const _color = Color(0xFF3F51B5);

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
              Text(_titleForTask(success),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: success ? _color : Colors.red[700]!)),
            ],
          ),
          const SizedBox(height: 12),
          if (!success)
            Text(result['error'] as String? ?? result['message'] as String? ?? 'Calculation failed',
                style: TextStyle(color: Colors.red[700]))
          else
            _buildResult(),
        ],
      ),
    );
  }

  Widget _buildResult() {
    switch (taskType) {
      case 'calculator_eval':
        return _buildEvalResult();
      case 'calculator_convert':
        return _buildConvertResult();
      case 'calculator_timezone':
        return _buildTimezoneResult();
      case 'calculator_date_math':
        return _buildDateMathResult();
      default:
        return Text(result['result']?.toString() ?? '', style: const TextStyle(fontSize: 18));
    }
  }

  Widget _buildEvalResult() {
    final expression = result['expression'] as String? ?? '';
    final answer = result['result'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (expression.isNotEmpty)
          Text(expression, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          '= $answer',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _color),
        ),
      ],
    );
  }

  Widget _buildConvertResult() {
    // Use 'display' if available (daemon provides full formatted string)
    final display = result['display'] as String?;
    if (display != null && display.isNotEmpty) {
      return Text(display, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _color));
    }
    // Fallback: construct from individual fields
    final from = result['value'] ?? result['from_value'];
    final fromUnit = (result['from'] ?? result['from_unit'] ?? '') as String;
    final to = result['result'] ?? result['to_value'];
    final toUnit = (result['to'] ?? result['to_unit'] ?? '') as String;
    return Text(
      '$from $fromUnit = $to $toUnit',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _color),
    );
  }

  Widget _buildTimezoneResult() {
    // Prefer 'display' for full string, else construct from fields
    final display = result['display'] as String?;
    if (display != null && display.isNotEmpty) {
      return Text(display, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _color));
    }
    final city = (result['location'] ?? result['city'] ?? '') as String;
    final time = result['time'] as String? ?? '';
    final offset = result['offset'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${city[0].toUpperCase()}${city.substring(1)}${offset.isNotEmpty ? ' ($offset)' : ''}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        Text(time, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _color)),
      ],
    );
  }

  Widget _buildDateMathResult() {
    final display = result['display'] as String?;
    if (display != null && display.isNotEmpty) {
      return Text(display, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _color));
    }
    final answer = result['result'] ?? result['days'];
    final message = (result['message'] ?? '$answer') as String;
    return Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _color));
  }

  IconData _iconForTask() {
    switch (taskType) {
      case 'calculator_eval': return Icons.calculate;
      case 'calculator_convert': return Icons.swap_horiz;
      case 'calculator_timezone': return Icons.access_time;
      case 'calculator_date_math': return Icons.date_range;
      default: return Icons.calculate;
    }
  }

  String _titleForTask(bool success) {
    if (!success) return 'Calculator Error';
    switch (taskType) {
      case 'calculator_eval': return 'Calculator';
      case 'calculator_convert': return 'Conversion';
      case 'calculator_timezone': return 'Time Zone';
      case 'calculator_date_math': return 'Date Math';
      default: return 'Calculator';
    }
  }
}
