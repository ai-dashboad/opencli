import 'dart:math' as math;
import '../domain.dart';

class CalculatorDomain extends TaskDomain {
  @override
  String get id => 'calculator';
  @override
  String get name => 'Calculator & Conversions';
  @override
  String get description =>
      'Math calculations, unit conversions, timezone, and date math';
  @override
  String get icon => 'calculate';
  @override
  int get colorHex => 0xFF3F51B5;

  @override
  List<String> get taskTypes => [
        'calculator_eval',
        'calculator_convert',
        'calculator_timezone',
        'calculator_date_math',
      ];

  @override
  List<DomainIntentPattern> get intentPatterns => [
        // "calculate 15 + 20" or "what is 15% of 234"
        DomainIntentPattern(
          pattern: RegExp(r'^(?:calculate|calc|compute|what\s+is)\s+(.+)$',
              caseSensitive: false),
          taskType: 'calculator_eval',
          extractData: (m) => {'expression': m.group(1)!.trim()},
        ),
        // "15% of 234"
        DomainIntentPattern(
          pattern: RegExp(r'^(\d+(?:\.\d+)?)\s*%\s*(?:of)\s+(\d+(?:\.\d+)?)$',
              caseSensitive: false),
          taskType: 'calculator_eval',
          extractData: (m) => {'expression': '${m.group(1)}% of ${m.group(2)}'},
        ),
        // "convert 5 miles to km"
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:convert\s+)?(\d+(?:\.\d+)?)\s*(\w+)\s+(?:to|in|into)\s+(\w+)$',
              caseSensitive: false),
          taskType: 'calculator_convert',
          extractData: (m) => {
            'value': double.parse(m.group(1)!),
            'from': m.group(2)!,
            'to': m.group(3)!
          },
        ),
        // "what time is it in Tokyo"
        DomainIntentPattern(
          pattern: RegExp(r'^(?:what\s+time\s+(?:is\s+it\s+)?in)\s+(.+)$',
              caseSensitive: false),
          taskType: 'calculator_timezone',
          extractData: (m) => {'location': m.group(1)!.trim()},
        ),
        // "how many days until December 25"
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:how\s+many\s+days?\s+(?:until|till|to))\s+(.+)$',
              caseSensitive: false),
          taskType: 'calculator_date_math',
          extractData: (m) =>
              {'target': m.group(1)!.trim(), 'operation': 'days_until'},
        ),
        // "30 days from now"
        DomainIntentPattern(
          pattern: RegExp(r'^(\d+)\s+days?\s+from\s+(?:now|today)$',
              caseSensitive: false),
          taskType: 'calculator_date_math',
          extractData: (m) =>
              {'days': int.parse(m.group(1)!), 'operation': 'days_from_now'},
        ),
      ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
        DomainOllamaIntent(
          intentName: 'calculator_eval',
          description: 'Evaluate a math expression or percentage calculation',
          parameters: {'expression': 'math expression to evaluate'},
          examples: [
            OllamaExample(
                input: 'what is 15% of 234',
                intentJson:
                    '{"intent": "calculator_eval", "confidence": 0.95, "parameters": {"expression": "15% of 234"}}'),
            OllamaExample(
                input: 'calculate sqrt of 144',
                intentJson:
                    '{"intent": "calculator_eval", "confidence": 0.95, "parameters": {"expression": "sqrt(144)"}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'calculator_convert',
          description: 'Convert between units (distance, temperature, weight)',
          parameters: {
            'value': 'number',
            'from': 'source unit',
            'to': 'target unit'
          },
          examples: [
            OllamaExample(
                input: '5 miles to km',
                intentJson:
                    '{"intent": "calculator_convert", "confidence": 0.95, "parameters": {"value": 5, "from": "miles", "to": "km"}}'),
            OllamaExample(
                input: '100 fahrenheit to celsius',
                intentJson:
                    '{"intent": "calculator_convert", "confidence": 0.95, "parameters": {"value": 100, "from": "fahrenheit", "to": "celsius"}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'calculator_timezone',
          description: 'Check current time in a city or timezone',
          parameters: {'location': 'city or timezone name'},
          examples: [
            OllamaExample(
                input: 'what time is it in Tokyo',
                intentJson:
                    '{"intent": "calculator_timezone", "confidence": 0.95, "parameters": {"location": "Tokyo"}}'),
          ],
        ),
      ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
        'calculator_eval': const DomainDisplayConfig(
          cardType: 'calculator',
          titleTemplate: 'Calculator',
          icon: 'calculate',
          colorHex: 0xFF3F51B5,
        ),
        'calculator_convert': const DomainDisplayConfig(
          cardType: 'calculator',
          titleTemplate: 'Conversion',
          icon: 'swap_horiz',
          colorHex: 0xFF3F51B5,
        ),
        'calculator_timezone': const DomainDisplayConfig(
          cardType: 'calculator',
          titleTemplate: 'Timezone',
          icon: 'public',
          colorHex: 0xFF3F51B5,
        ),
        'calculator_date_math': const DomainDisplayConfig(
          cardType: 'calculator',
          titleTemplate: 'Date Calculation',
          icon: 'date_range',
          colorHex: 0xFF3F51B5,
        ),
      };

  @override
  Future<Map<String, dynamic>> executeTask(
      String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'calculator_eval':
        return _evaluate(data);
      case 'calculator_convert':
        return _convert(data);
      case 'calculator_timezone':
        return _timezone(data);
      case 'calculator_date_math':
        return _dateMath(data);
      default:
        return {
          'success': false,
          'error': 'Unknown calculator task: $taskType'
        };
    }
  }

  Map<String, dynamic> _evaluate(Map<String, dynamic> data) {
    final expr = data['expression'] as String? ?? '';
    try {
      // Handle percentage: "15% of 234"
      final percentMatch =
          RegExp(r'(\d+(?:\.\d+)?)\s*%\s*(?:of)\s+(\d+(?:\.\d+)?)')
              .firstMatch(expr);
      if (percentMatch != null) {
        final pct = double.parse(percentMatch.group(1)!);
        final value = double.parse(percentMatch.group(2)!);
        final result = (pct / 100) * value;
        return {
          'success': true,
          'expression': expr,
          'result': _formatNumber(result),
          'domain': 'calculator',
          'card_type': 'calculator'
        };
      }

      // Handle sqrt
      final sqrtMatch =
          RegExp(r'sqrt\s*\(?(\d+(?:\.\d+)?)\)?').firstMatch(expr);
      if (sqrtMatch != null) {
        final val = double.parse(sqrtMatch.group(1)!);
        return {
          'success': true,
          'expression': expr,
          'result': _formatNumber(math.sqrt(val)),
          'domain': 'calculator',
          'card_type': 'calculator'
        };
      }

      // Handle power: "2^10" or "2 power 10"
      final powMatch =
          RegExp(r'(\d+(?:\.\d+)?)\s*[\^]\s*(\d+(?:\.\d+)?)').firstMatch(expr);
      if (powMatch != null) {
        final base = double.parse(powMatch.group(1)!);
        final exp = double.parse(powMatch.group(2)!);
        return {
          'success': true,
          'expression': expr,
          'result': _formatNumber(math.pow(base, exp).toDouble()),
          'domain': 'calculator',
          'card_type': 'calculator'
        };
      }

      // Simple arithmetic: parse basic +, -, *, /
      final result = _simpleEval(expr);
      if (result != null) {
        return {
          'success': true,
          'expression': expr,
          'result': _formatNumber(result),
          'domain': 'calculator',
          'card_type': 'calculator'
        };
      }

      return {
        'success': false,
        'expression': expr,
        'error': 'Could not evaluate expression',
        'domain': 'calculator'
      };
    } catch (e) {
      return {
        'success': false,
        'expression': expr,
        'error': 'Calculation error: $e',
        'domain': 'calculator'
      };
    }
  }

  double? _simpleEval(String expr) {
    // Clean expression
    var cleaned = expr.replaceAll(RegExp(r'[^\d\+\-\*\/\.\(\)\s]'), '').trim();
    if (cleaned.isEmpty) return null;

    try {
      // Handle basic operations: supports +, -, *, /
      // Split by + and - (respecting order of operations)
      final parts = cleaned.split(RegExp(r'\s*[\+]\s*'));
      if (parts.length > 1) {
        double sum = 0;
        for (final part in parts) {
          final val = _simpleEval(part);
          if (val == null) return null;
          sum += val;
        }
        return sum;
      }

      // Handle subtraction
      if (cleaned.contains('-') && !cleaned.startsWith('-')) {
        final idx = cleaned.lastIndexOf('-');
        final left = _simpleEval(cleaned.substring(0, idx).trim());
        final right = _simpleEval(cleaned.substring(idx + 1).trim());
        if (left != null && right != null) return left - right;
      }

      // Handle multiplication
      if (cleaned.contains('*')) {
        final mParts = cleaned.split('*');
        double product = 1;
        for (final part in mParts) {
          final val = _simpleEval(part.trim());
          if (val == null) return null;
          product *= val;
        }
        return product;
      }

      // Handle division
      if (cleaned.contains('/')) {
        final dParts = cleaned.split('/');
        if (dParts.length == 2) {
          final left = _simpleEval(dParts[0].trim());
          final right = _simpleEval(dParts[1].trim());
          if (left != null && right != null && right != 0) return left / right;
        }
      }

      return double.tryParse(cleaned);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _convert(Map<String, dynamic> data) {
    final value = (data['value'] as num?)?.toDouble() ?? 0;
    final from = (data['from'] as String? ?? '').toLowerCase();
    final to = (data['to'] as String? ?? '').toLowerCase();

    final conversions = <String, Map<String, double>>{
      'miles': {'km': 1.60934, 'meters': 1609.34, 'feet': 5280},
      'km': {'miles': 0.621371, 'meters': 1000, 'feet': 3280.84},
      'meters': {
        'feet': 3.28084,
        'miles': 0.000621371,
        'km': 0.001,
        'inches': 39.3701
      },
      'feet': {
        'meters': 0.3048,
        'miles': 0.000189394,
        'km': 0.0003048,
        'inches': 12
      },
      'inches': {'cm': 2.54, 'meters': 0.0254, 'feet': 0.0833333},
      'cm': {'inches': 0.393701, 'meters': 0.01, 'feet': 0.0328084},
      'kg': {'lbs': 2.20462, 'pounds': 2.20462, 'oz': 35.274, 'grams': 1000},
      'lbs': {'kg': 0.453592, 'oz': 16, 'grams': 453.592},
      'pounds': {'kg': 0.453592, 'oz': 16, 'grams': 453.592},
      'oz': {'grams': 28.3495, 'kg': 0.0283495, 'lbs': 0.0625},
      'grams': {'oz': 0.035274, 'kg': 0.001, 'lbs': 0.00220462},
      'liters': {'gallons': 0.264172, 'cups': 4.22675, 'ml': 1000},
      'gallons': {'liters': 3.78541, 'cups': 16, 'ml': 3785.41},
      'cups': {'ml': 236.588, 'liters': 0.236588, 'gallons': 0.0625},
    };

    // Temperature special handling
    if (_isTemp(from) && _isTemp(to)) {
      final result = _convertTemp(value, from, to);
      if (result != null) {
        return {
          'success': true,
          'value': value,
          'from': from,
          'to': to,
          'result': _formatNumber(result),
          'display':
              '${_formatNumber(value)} $from = ${_formatNumber(result)} $to',
          'domain': 'calculator',
          'card_type': 'calculator',
        };
      }
    }

    final fromMap = conversions[from];
    if (fromMap != null && fromMap.containsKey(to)) {
      final result = value * fromMap[to]!;
      return {
        'success': true,
        'value': value,
        'from': from,
        'to': to,
        'result': _formatNumber(result),
        'display':
            '${_formatNumber(value)} $from = ${_formatNumber(result)} $to',
        'domain': 'calculator',
        'card_type': 'calculator',
      };
    }

    return {
      'success': false,
      'error': 'Unknown conversion: $from to $to',
      'domain': 'calculator'
    };
  }

  bool _isTemp(String unit) {
    return ['fahrenheit', 'celsius', 'kelvin', 'f', 'c', 'k'].contains(unit);
  }

  double? _convertTemp(double value, String from, String to) {
    final f = from.startsWith('f')
        ? 'f'
        : from.startsWith('c')
            ? 'c'
            : 'k';
    final t = to.startsWith('f')
        ? 'f'
        : to.startsWith('c')
            ? 'c'
            : 'k';
    if (f == t) return value;
    if (f == 'f' && t == 'c') return (value - 32) * 5 / 9;
    if (f == 'c' && t == 'f') return value * 9 / 5 + 32;
    if (f == 'c' && t == 'k') return value + 273.15;
    if (f == 'k' && t == 'c') return value - 273.15;
    if (f == 'f' && t == 'k') return (value - 32) * 5 / 9 + 273.15;
    if (f == 'k' && t == 'f') return (value - 273.15) * 9 / 5 + 32;
    return null;
  }

  Map<String, dynamic> _timezone(Map<String, dynamic> data) {
    final location = (data['location'] as String? ?? '').toLowerCase();
    final tzOffsets = <String, int>{
      'tokyo': 9,
      'japan': 9,
      'jst': 9,
      'london': 0,
      'uk': 0,
      'gmt': 0,
      'utc': 0,
      'new york': -5,
      'nyc': -5,
      'est': -5,
      'eastern': -5,
      'los angeles': -8,
      'la': -8,
      'pst': -8,
      'pacific': -8,
      'chicago': -6,
      'cst': -6,
      'central': -6,
      'denver': -7,
      'mst': -7,
      'mountain': -7,
      'paris': 1,
      'france': 1,
      'cet': 1,
      'berlin': 1,
      'germany': 1,
      'sydney': 11,
      'australia': 11,
      'aest': 11,
      'beijing': 8,
      'china': 8,
      'shanghai': 8,
      'cst_china': 8,
      'mumbai': 5,
      'india': 5,
      'ist': 5,
      'delhi': 5,
      'dubai': 4,
      'uae': 4,
      'singapore': 8,
      'hong kong': 8,
      'seoul': 9,
      'korea': 9,
      'bangkok': 7,
      'thailand': 7,
      'moscow': 3,
      'russia': 3,
      'sao paulo': -3,
      'brazil': -3,
      'hawaii': -10,
      'hst': -10,
    };

    final offset = tzOffsets[location];
    if (offset == null) {
      return {
        'success': false,
        'error': 'Unknown timezone/city: $location',
        'domain': 'calculator'
      };
    }

    final utcNow = DateTime.now().toUtc();
    final localTime = utcNow.add(Duration(hours: offset));
    final formatted =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';

    return {
      'success': true,
      'location': location,
      'time': formatted,
      'date': dateStr,
      'offset': 'UTC${offset >= 0 ? '+' : ''}$offset',
      'display':
          'It\'s $formatted in ${location[0].toUpperCase()}${location.substring(1)} ($dateStr, UTC${offset >= 0 ? '+' : ''}$offset)',
      'domain': 'calculator',
      'card_type': 'calculator',
    };
  }

  Map<String, dynamic> _dateMath(Map<String, dynamic> data) {
    final operation = data['operation'] as String? ?? '';
    final now = DateTime.now();

    if (operation == 'days_from_now') {
      final days = (data['days'] as num?)?.toInt() ?? 0;
      final target = now.add(Duration(days: days));
      final dateStr =
          '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
      return {
        'success': true,
        'days': days,
        'date': dateStr,
        'display': '$days days from now is $dateStr',
        'domain': 'calculator',
        'card_type': 'calculator',
      };
    }

    if (operation == 'days_until') {
      final target = data['target'] as String? ?? '';
      final targetDate = _parseDate(target);
      if (targetDate == null) {
        return {
          'success': false,
          'error': 'Could not parse date: $target',
          'domain': 'calculator'
        };
      }
      final days = targetDate.difference(now).inDays;
      return {
        'success': true,
        'target': target,
        'days': days,
        'display': '$days days until $target',
        'domain': 'calculator',
        'card_type': 'calculator',
      };
    }

    return {
      'success': false,
      'error': 'Unknown date operation',
      'domain': 'calculator'
    };
  }

  DateTime? _parseDate(String text) {
    final lower = text.toLowerCase().trim();
    final now = DateTime.now();

    // Common holidays
    final year = now.year;
    final holidays = {
      'christmas': DateTime(year, 12, 25),
      'new year': DateTime(year + 1, 1, 1),
      'new years': DateTime(year + 1, 1, 1),
      'valentines': DateTime(year, 2, 14),
      'valentine': DateTime(year, 2, 14),
      'halloween': DateTime(year, 10, 31),
      'thanksgiving': DateTime(year, 11, 28),
    };
    if (holidays.containsKey(lower)) {
      var d = holidays[lower]!;
      if (d.isBefore(now)) d = DateTime(year + 1, d.month, d.day);
      return d;
    }

    // Month Day format: "december 25", "march 1"
    final months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12
    };
    for (final entry in months.entries) {
      final match = RegExp('${entry.key}\\s+(\\d+)').firstMatch(lower);
      if (match != null) {
        var d = DateTime(year, entry.value, int.parse(match.group(1)!));
        if (d.isBefore(now))
          d = DateTime(year + 1, entry.value, int.parse(match.group(1)!));
        return d;
      }
    }

    return null;
  }

  String _formatNumber(double n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }
}
