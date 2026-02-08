import 'video_provider.dart';
import 'replicate_provider.dart';
import 'runway_provider.dart';
import 'kling_provider.dart';
import 'luma_provider.dart';

/// Registry of all AI video providers.
/// Configured from ~/.opencli/config.yaml during domain initialization.
class VideoProviderRegistry {
  final Map<String, AIVideoProvider> _providers = {};

  VideoProviderRegistry() {
    _register(ReplicateVideoProvider());
    _register(RunwayVideoProvider());
    _register(KlingVideoProvider());
    _register(LumaVideoProvider());
  }

  void _register(AIVideoProvider provider) {
    _providers[provider.id] = provider;
  }

  AIVideoProvider? get(String id) => _providers[id];

  List<AIVideoProvider> get allProviders => _providers.values.toList();

  List<AIVideoProvider> get configuredProviders =>
      _providers.values.where((p) => p.isConfigured).toList();

  /// Configure providers from config.yaml ai_video section.
  void configureFromConfig(Map<String, dynamic> aiVideoConfig) {
    final keys = aiVideoConfig['api_keys'] as Map? ?? {};
    for (final entry in keys.entries) {
      final key = entry.key as String;
      final value = entry.value as String?;
      if (value == null || value.isEmpty || value.startsWith(r'${')) continue;

      // Map config key names to provider IDs
      switch (key) {
        case 'replicate':
          _providers['replicate']?.configure(value);
        case 'runway':
          _providers['runway']?.configure(value);
        case 'kling_piapi':
          _providers['kling']?.configure(value);
        case 'luma':
          _providers['luma']?.configure(value);
      }
    }
  }
}
