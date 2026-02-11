import 'tts_provider.dart';
import 'edge_tts_provider.dart';
import 'elevenlabs_provider.dart';

/// Registry for TTS providers, mirroring VideoProviderRegistry.
class TTSRegistry {
  final Map<String, TTSProvider> _providers = {};

  TTSRegistry() {
    _register(EdgeTTSProvider());
    _register(ElevenLabsProvider());
  }

  void _register(TTSProvider provider) {
    _providers[provider.id] = provider;
  }

  TTSProvider? get(String id) => _providers[id];

  List<TTSProvider> get allProviders => _providers.values.toList();

  List<TTSProvider> get configuredProviders =>
      _providers.values.where((p) => p.isConfigured).toList();

  /// The default provider — Edge TTS (free, always available).
  TTSProvider get defaultProvider =>
      _providers['edge_tts'] ?? _providers.values.first;

  /// Configure providers from config.yaml tts section.
  void configureFromConfig(Map<String, dynamic> ttsConfig) {
    final keys = ttsConfig['api_keys'] as Map? ?? {};
    for (final entry in keys.entries) {
      final key = entry.key as String;
      final value = entry.value as String?;
      if (value == null || value.isEmpty) continue;

      switch (key) {
        case 'elevenlabs':
          _providers['elevenlabs']?.configure(value);
          break;
      }
    }
  }
}
