/// OpenCLI Capabilities Module
///
/// Provides hot-updatable capability packages for extending daemon functionality.
///
/// Usage:
/// ```dart
/// final loader = CapabilityLoader();
/// final registry = CapabilityRegistry(loader: loader);
/// final executor = CapabilityExecutor(registry: registry);
/// final updater = CapabilityUpdater(registry: registry, loader: loader);
///
/// await registry.initialize();
/// updater.start();
///
/// // Execute a capability
/// final result = await executor.execute('desktop.open_app', {'app_name': 'Chrome'});
/// ```

library capabilities;

export 'capability_schema.dart';
export 'capability_loader.dart';
export 'capability_registry.dart';
export 'capability_updater.dart';
export 'capability_executor.dart';
