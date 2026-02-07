import 'package:flutter/material.dart';

/// Weather domain card — shows temperature, conditions, forecast.
class WeatherCard extends StatelessWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const WeatherCard({Key? key, required this.taskType, required this.result}) : super(key: key);

  static const _color = Color(0xFF03A9F4);

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.1), Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!success)
            Text(result['error'] as String? ?? result['message'] as String? ?? 'Weather unavailable',
                style: TextStyle(color: Colors.red[700]))
          else if (taskType == 'weather_forecast')
            _buildForecast()
          else
            _buildCurrent(),
        ],
      ),
    );
  }

  Widget _buildCurrent() {
    final location = result['location'] as String? ?? '';
    final tempC = result['temperature_c'] as String? ?? '';
    final tempF = result['temperature_f'] as String? ?? '';
    final condition = result['condition'] as String? ?? '';
    final humidity = result['humidity'] as String? ?? '';
    final windMph = result['wind_mph'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (location.isNotEmpty)
          Text(location, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_weatherIcon(condition), color: _color, size: 48),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$tempC\u00B0C / $tempF\u00B0F',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(condition, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (humidity.isNotEmpty) ...[
              Icon(Icons.water_drop, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('$humidity%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 16),
            ],
            if (windMph.isNotEmpty) ...[
              Icon(Icons.air, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('$windMph mph', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildForecast() {
    final location = result['location'] as String? ?? '';
    final days = result['days'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wb_sunny, color: _color, size: 24),
            const SizedBox(width: 8),
            Text('Forecast${location.isNotEmpty ? " - $location" : ""}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _color)),
          ],
        ),
        const SizedBox(height: 12),
        ...days.take(5).map((day) {
          final d = day as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(d['date'] as String? ?? '', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text(d['condition'] as String? ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                Text('${d['max_c']}\u00B0/${d['min_c']}\u00B0', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }),
      ],
    );
  }

  IconData _weatherIcon(String condition) {
    final lower = condition.toLowerCase();
    if (lower.contains('sun') || lower.contains('clear')) return Icons.wb_sunny;
    if (lower.contains('cloud') || lower.contains('overcast')) return Icons.cloud;
    if (lower.contains('rain') || lower.contains('drizzle')) return Icons.water_drop;
    if (lower.contains('snow')) return Icons.ac_unit;
    if (lower.contains('thunder') || lower.contains('storm')) return Icons.flash_on;
    if (lower.contains('fog') || lower.contains('mist')) return Icons.blur_on;
    return Icons.cloud;
  }
}
