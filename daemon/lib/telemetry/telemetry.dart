/// OpenCLI Telemetry Module
///
/// Provides error collection, automatic issue reporting, and usage analytics.
/// All data is anonymized by default and requires user consent.
///
/// Usage:
/// ```dart
/// final telemetry = TelemetryManager(
///   appVersion: '0.2.0',
///   deviceId: 'device-123',
/// );
/// await telemetry.initialize();
///
/// // Record errors
/// telemetry.recordError('Something went wrong');
/// telemetry.recordException(exception, stackTrace);
/// ```

library telemetry;

export 'error_collector.dart';
export 'issue_reporter.dart';
export 'telemetry_config.dart';
