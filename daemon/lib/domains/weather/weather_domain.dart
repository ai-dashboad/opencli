import 'dart:io';
import 'dart:convert';
import '../domain.dart';

class WeatherDomain extends TaskDomain {
  @override
  String get id => 'weather';
  @override
  String get name => 'Weather';
  @override
  String get description => 'Check current weather and forecast (uses wttr.in)';
  @override
  String get icon => 'cloud';
  @override
  int get colorHex => 0xFF03A9F4;

  @override
  List<String> get taskTypes => ['weather_current', 'weather_forecast'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
    DomainIntentPattern(
      pattern: RegExp(r'^(?:weather|temperature|temp)(?:\s+(?:in|for|at)\s+(.+?))?(?:\s+tomorrow)?$', caseSensitive: false),
      taskType: 'weather_current',
      extractData: (m) => {'location': m.group(1) ?? ''},
    ),
    DomainIntentPattern(
      pattern: RegExp(r"^(?:what'?s?\s+the\s+weather)(?:\s+(?:in|for|at)\s+(.+?))?(?:\s+(today|tomorrow))?$", caseSensitive: false),
      taskType: 'weather_current',
      extractData: (m) => {'location': m.group(1) ?? '', 'day': m.group(2) ?? 'today'},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(?:is\s+it\s+going\s+to\s+rain|will\s+it\s+rain)(?:\s+(today|tomorrow))?$', caseSensitive: false),
      taskType: 'weather_current',
      extractData: (m) => {'day': m.group(1) ?? 'today'},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(?:weather\s+)?forecast(?:\s+(?:for\s+)?(.+))?$', caseSensitive: false),
      taskType: 'weather_forecast',
      extractData: (m) => {'location': m.group(1) ?? ''},
    ),
  ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
    DomainOllamaIntent(
      intentName: 'weather_current',
      description: 'Get current weather conditions',
      parameters: {'location': 'optional city name'},
      examples: [
        OllamaExample(input: "what's the weather", intentJson: '{"intent": "weather_current", "confidence": 0.95, "parameters": {}}'),
        OllamaExample(input: 'weather in Tokyo', intentJson: '{"intent": "weather_current", "confidence": 0.95, "parameters": {"location": "Tokyo"}}'),
        OllamaExample(input: 'is it going to rain tomorrow', intentJson: '{"intent": "weather_current", "confidence": 0.95, "parameters": {"day": "tomorrow"}}'),
      ],
    ),
    DomainOllamaIntent(
      intentName: 'weather_forecast',
      description: 'Get weather forecast for the next few days',
      parameters: {'location': 'optional city name'},
      examples: [
        OllamaExample(input: 'forecast for this week', intentJson: '{"intent": "weather_forecast", "confidence": 0.95, "parameters": {}}'),
      ],
    ),
  ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
    'weather_current': const DomainDisplayConfig(cardType: 'weather', titleTemplate: 'Weather', icon: 'cloud', colorHex: 0xFF03A9F4),
    'weather_forecast': const DomainDisplayConfig(cardType: 'weather', titleTemplate: 'Forecast', icon: 'wb_sunny', colorHex: 0xFF03A9F4),
  };

  @override
  Future<Map<String, dynamic>> executeTask(String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'weather_current':
        return _currentWeather(data);
      case 'weather_forecast':
        return _forecast(data);
      default:
        return {'success': false, 'error': 'Unknown weather task: $taskType'};
    }
  }

  Future<Map<String, dynamic>> _currentWeather(Map<String, dynamic> data) async {
    final location = data['location'] as String? ?? '';
    try {
      final result = await Process.run('curl', ['-s', 'wttr.in/$location?format=j1'])
          .timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) {
        return {'success': false, 'error': 'Failed to fetch weather data', 'domain': 'weather'};
      }

      final json = jsonDecode(result.stdout as String);
      final current = json['current_condition']?[0];
      if (current == null) {
        return {'success': false, 'error': 'No weather data available', 'domain': 'weather'};
      }

      final area = json['nearest_area']?[0];
      final cityName = area?['areaName']?[0]?['value'] ?? location;
      final country = area?['country']?[0]?['value'] ?? '';

      return {
        'success': true,
        'location': '$cityName, $country'.trim().replaceAll(RegExp(r'^,\s*|,\s*$'), ''),
        'temperature_c': current['temp_C'],
        'temperature_f': current['temp_F'],
        'feels_like_c': current['FeelsLikeC'],
        'condition': current['weatherDesc']?[0]?['value'] ?? '',
        'humidity': current['humidity'],
        'wind_mph': current['windspeedMiles'],
        'wind_dir': current['winddir16Point'],
        'domain': 'weather', 'card_type': 'weather',
      };
    } catch (e) {
      return {'success': false, 'error': 'Weather error: $e', 'domain': 'weather'};
    }
  }

  Future<Map<String, dynamic>> _forecast(Map<String, dynamic> data) async {
    final location = data['location'] as String? ?? '';
    try {
      final result = await Process.run('curl', ['-s', 'wttr.in/$location?format=j1'])
          .timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) {
        return {'success': false, 'error': 'Failed to fetch forecast', 'domain': 'weather'};
      }

      final json = jsonDecode(result.stdout as String);
      final weather = json['weather'] as List<dynamic>?;
      if (weather == null || weather.isEmpty) {
        return {'success': false, 'error': 'No forecast data available', 'domain': 'weather'};
      }

      final area = json['nearest_area']?[0];
      final cityName = area?['areaName']?[0]?['value'] ?? location;

      final days = <Map<String, dynamic>>[];
      for (final day in weather) {
        days.add({
          'date': day['date'],
          'max_c': day['maxtempC'],
          'min_c': day['mintempC'],
          'max_f': day['maxtempF'],
          'min_f': day['mintempF'],
          'condition': day['hourly']?[4]?['weatherDesc']?[0]?['value'] ?? '',
        });
      }

      return {
        'success': true,
        'location': cityName,
        'days': days,
        'domain': 'weather', 'card_type': 'weather',
      };
    } catch (e) {
      return {'success': false, 'error': 'Forecast error: $e', 'domain': 'weather'};
    }
  }
}
