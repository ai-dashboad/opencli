import 'dart:async';
import 'dart:io';

/// Collects and exposes system metrics in Prometheus format
class MetricsCollector {
  final Map<String, Counter> _counters = {};
  final Map<String, Gauge> _gauges = {};
  final Map<String, Histogram> _histograms = {};
  final Map<String, Summary> _summaries = {};

  /// Register and get counter
  Counter counter(String name, {String? help, Map<String, String>? labels}) {
    final key = _metricKey(name, labels);
    return _counters.putIfAbsent(
      key,
      () => Counter(name: name, help: help, labels: labels),
    );
  }

  /// Register and get gauge
  Gauge gauge(String name, {String? help, Map<String, String>? labels}) {
    final key = _metricKey(name, labels);
    return _gauges.putIfAbsent(
      key,
      () => Gauge(name: name, help: help, labels: labels),
    );
  }

  /// Register and get histogram
  Histogram histogram(
    String name, {
    String? help,
    Map<String, String>? labels,
    List<double>? buckets,
  }) {
    final key = _metricKey(name, labels);
    return _histograms.putIfAbsent(
      key,
      () => Histogram(name: name, help: help, labels: labels, buckets: buckets),
    );
  }

  /// Register and get summary
  Summary summary(
    String name, {
    String? help,
    Map<String, String>? labels,
    List<double>? quantiles,
  }) {
    final key = _metricKey(name, labels);
    return _summaries.putIfAbsent(
      key,
      () => Summary(name: name, help: help, labels: labels, quantiles: quantiles),
    );
  }

  /// Export metrics in Prometheus format
  String exportPrometheus() {
    final buffer = StringBuffer();

    for (final counter in _counters.values) {
      buffer.write(counter.toPrometheus());
    }

    for (final gauge in _gauges.values) {
      buffer.write(gauge.toPrometheus());
    }

    for (final histogram in _histograms.values) {
      buffer.write(histogram.toPrometheus());
    }

    for (final summary in _summaries.values) {
      buffer.write(summary.toPrometheus());
    }

    return buffer.toString();
  }

  /// Export metrics as JSON
  Map<String, dynamic> exportJson() {
    return {
      'counters': _counters.map((k, v) => MapEntry(k, v.toJson())),
      'gauges': _gauges.map((k, v) => MapEntry(k, v.toJson())),
      'histograms': _histograms.map((k, v) => MapEntry(k, v.toJson())),
      'summaries': _summaries.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  /// Reset all metrics
  void reset() {
    _counters.values.forEach((c) => c.reset());
    _gauges.values.forEach((g) => g.reset());
    _histograms.values.forEach((h) => h.reset());
    _summaries.values.forEach((s) => s.reset());
  }

  String _metricKey(String name, Map<String, String>? labels) {
    if (labels == null || labels.isEmpty) return name;
    final labelStr = labels.entries.map((e) => '${e.key}="${e.value}"').join(',');
    return '$name{$labelStr}';
  }
}

/// Counter metric (only increases)
class Counter {
  final String name;
  final String? help;
  final Map<String, String>? labels;
  double _value = 0;

  Counter({required this.name, this.help, this.labels});

  /// Increment counter
  void inc([double amount = 1]) {
    _value += amount;
  }

  /// Get current value
  double get value => _value;

  /// Reset counter
  void reset() {
    _value = 0;
  }

  String toPrometheus() {
    final buffer = StringBuffer();
    if (help != null) {
      buffer.writeln('# HELP $name $help');
    }
    buffer.writeln('# TYPE $name counter');
    buffer.write(name);
    if (labels != null && labels!.isNotEmpty) {
      final labelStr = labels!.entries.map((e) => '${e.key}="${e.value}"').join(',');
      buffer.write('{$labelStr}');
    }
    buffer.writeln(' $_value');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': 'counter',
      'value': _value,
      if (labels != null) 'labels': labels,
    };
  }
}

/// Gauge metric (can go up and down)
class Gauge {
  final String name;
  final String? help;
  final Map<String, String>? labels;
  double _value = 0;

  Gauge({required this.name, this.help, this.labels});

  /// Set gauge value
  void set(double value) {
    _value = value;
  }

  /// Increment gauge
  void inc([double amount = 1]) {
    _value += amount;
  }

  /// Decrement gauge
  void dec([double amount = 1]) {
    _value -= amount;
  }

  /// Set to current time
  void setToCurrentTime() {
    _value = DateTime.now().millisecondsSinceEpoch / 1000;
  }

  /// Get current value
  double get value => _value;

  /// Reset gauge
  void reset() {
    _value = 0;
  }

  String toPrometheus() {
    final buffer = StringBuffer();
    if (help != null) {
      buffer.writeln('# HELP $name $help');
    }
    buffer.writeln('# TYPE $name gauge');
    buffer.write(name);
    if (labels != null && labels!.isNotEmpty) {
      final labelStr = labels!.entries.map((e) => '${e.key}="${e.value}"').join(',');
      buffer.write('{$labelStr}');
    }
    buffer.writeln(' $_value');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': 'gauge',
      'value': _value,
      if (labels != null) 'labels': labels,
    };
  }
}

/// Histogram metric (for distributions)
class Histogram {
  final String name;
  final String? help;
  final Map<String, String>? labels;
  final List<double> buckets;
  final Map<double, int> _bucketCounts = {};
  double _sum = 0;
  int _count = 0;

  Histogram({
    required this.name,
    this.help,
    this.labels,
    List<double>? buckets,
  }) : buckets = buckets ?? [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10] {
    for (final bucket in this.buckets) {
      _bucketCounts[bucket] = 0;
    }
    _bucketCounts[double.infinity] = 0;
  }

  /// Observe a value
  void observe(double value) {
    _sum += value;
    _count++;

    for (final bucket in buckets) {
      if (value <= bucket) {
        _bucketCounts[bucket] = (_bucketCounts[bucket] ?? 0) + 1;
      }
    }
    _bucketCounts[double.infinity] = (_bucketCounts[double.infinity] ?? 0) + 1;
  }

  /// Reset histogram
  void reset() {
    _sum = 0;
    _count = 0;
    _bucketCounts.clear();
    for (final bucket in buckets) {
      _bucketCounts[bucket] = 0;
    }
    _bucketCounts[double.infinity] = 0;
  }

  String toPrometheus() {
    final buffer = StringBuffer();
    if (help != null) {
      buffer.writeln('# HELP $name $help');
    }
    buffer.writeln('# TYPE $name histogram');

    final labelStr = labels != null && labels!.isNotEmpty
        ? labels!.entries.map((e) => '${e.key}="${e.value}"').join(',')
        : '';

    for (final entry in _bucketCounts.entries) {
      final bucketLabel = entry.key == double.infinity ? '+Inf' : entry.key.toString();
      buffer.write('${name}_bucket{');
      if (labelStr.isNotEmpty) buffer.write('$labelStr,');
      buffer.writeln('le="$bucketLabel"} ${entry.value}');
    }

    buffer.write('${name}_sum');
    if (labelStr.isNotEmpty) buffer.write('{$labelStr}');
    buffer.writeln(' $_sum');

    buffer.write('${name}_count');
    if (labelStr.isNotEmpty) buffer.write('{$labelStr}');
    buffer.writeln(' $_count');

    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': 'histogram',
      'sum': _sum,
      'count': _count,
      'buckets': _bucketCounts,
      if (labels != null) 'labels': labels,
    };
  }
}

/// Summary metric (for quantiles)
class Summary {
  final String name;
  final String? help;
  final Map<String, String>? labels;
  final List<double> quantiles;
  final List<double> _observations = [];
  double _sum = 0;
  int _count = 0;

  Summary({
    required this.name,
    this.help,
    this.labels,
    List<double>? quantiles,
  }) : quantiles = quantiles ?? [0.5, 0.9, 0.99];

  /// Observe a value
  void observe(double value) {
    _observations.add(value);
    _sum += value;
    _count++;
  }

  /// Calculate quantile
  double _calculateQuantile(double q) {
    if (_observations.isEmpty) return 0;

    final sorted = List<double>.from(_observations)..sort();
    final index = (q * sorted.length).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Reset summary
  void reset() {
    _observations.clear();
    _sum = 0;
    _count = 0;
  }

  String toPrometheus() {
    final buffer = StringBuffer();
    if (help != null) {
      buffer.writeln('# HELP $name $help');
    }
    buffer.writeln('# TYPE $name summary');

    final labelStr = labels != null && labels!.isNotEmpty
        ? labels!.entries.map((e) => '${e.key}="${e.value}"').join(',')
        : '';

    for (final q in quantiles) {
      buffer.write(name);
      buffer.write('{');
      if (labelStr.isNotEmpty) buffer.write('$labelStr,');
      buffer.writeln('quantile="$q"} ${_calculateQuantile(q)}');
    }

    buffer.write('${name}_sum');
    if (labelStr.isNotEmpty) buffer.write('{$labelStr}');
    buffer.writeln(' $_sum');

    buffer.write('${name}_count');
    if (labelStr.isNotEmpty) buffer.write('{$labelStr}');
    buffer.writeln(' $_count');

    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': 'summary',
      'sum': _sum,
      'count': _count,
      'quantiles': {
        for (final q in quantiles) q.toString(): _calculateQuantile(q),
      },
      if (labels != null) 'labels': labels,
    };
  }
}

/// System metrics collector
class SystemMetricsCollector {
  final MetricsCollector metrics;
  Timer? _timer;

  SystemMetricsCollector(this.metrics);

  /// Start collecting system metrics
  void start({Duration interval = const Duration(seconds: 15)}) {
    _timer = Timer.periodic(interval, (_) => _collect());
    _collect(); // Collect immediately
  }

  /// Stop collecting
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _collect() {
    // CPU usage
    final cpuGauge = metrics.gauge('system_cpu_usage', help: 'System CPU usage');
    // Note: Getting actual CPU usage requires platform-specific code
    // This is a placeholder
    cpuGauge.set(0.0);

    // Memory usage
    final memoryGauge = metrics.gauge('system_memory_bytes', help: 'System memory usage in bytes');
    // Note: Getting actual memory usage requires platform-specific code
    memoryGauge.set(0.0);

    // Process count
    final processGauge = metrics.gauge('system_process_count', help: 'Number of running processes');
    processGauge.set(ProcessInfo.currentRss.toDouble());

    // Uptime
    final uptimeGauge = metrics.gauge('system_uptime_seconds', help: 'System uptime in seconds');
    uptimeGauge.setToCurrentTime();
  }
}
