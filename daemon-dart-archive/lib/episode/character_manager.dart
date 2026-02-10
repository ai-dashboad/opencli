import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';
import '../domains/media_creation/local_model_manager.dart';
import 'episode_script.dart';

/// Manages character reference images, CLIP embeddings, and consistent generation.
///
/// Integrates with IP-Adapter for face consistency across shots.
/// Stores reference images and embeddings in the database.
class CharacterManager {
  final AppDatabase _db;
  final LocalModelManager? _localModelManager;

  CharacterManager(this._db, [this._localModelManager]);

  /// Save a character reference with image.
  Future<void> saveReference({
    required String characterId,
    required String name,
    String? episodeId,
    String? visualDescription,
    List<int>? referenceImage,
    String? defaultVoice,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.db.insert(
      'character_references',
      {
        'id': '${characterId}_$now',
        'episode_id': episodeId,
        'character_id': characterId,
        'name': name,
        'visual_description': visualDescription ?? '',
        'reference_image': referenceImage,
        'embedding': null,
        'default_voice': defaultVoice ?? 'zh-CN-XiaoxiaoNeural',
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save a reference image and encode it via IP-Adapter.
  ///
  /// Returns the embedding path for use in generation.
  Future<String?> saveAndEncodeReference({
    required String characterId,
    required String name,
    required String imageBase64,
    String? episodeId,
    String? visualDescription,
    String? defaultVoice,
  }) async {
    final imageBytes = base64Decode(imageBase64);

    // Save to database
    await saveReference(
      characterId: characterId,
      name: name,
      episodeId: episodeId,
      visualDescription: visualDescription,
      referenceImage: imageBytes,
      defaultVoice: defaultVoice,
    );

    // Encode via IP-Adapter if local model manager is available
    if (_localModelManager == null) return null;

    try {
      final result = await _localModelManager!.runIPAdapter(
        action: 'encode_reference',
        params: {
          'image_base64': imageBase64,
          'character_id': characterId,
        },
      );

      if (result.success) {
        // Store embedding path in most recent reference
        final refs = await getReferences(characterId);
        if (refs.isNotEmpty) {
          final refId = refs.first['id'] as String;
          final embeddingPath = result.data['embedding_path'] as String?;
          if (embeddingPath != null) {
            await _db.db.update(
              'character_references',
              {'embedding': embeddingPath},
              where: 'id = ?',
              whereArgs: [refId],
            );
          }
        }
        return result.data['embedding_path'] as String?;
      }
    } catch (e) {
      print('[CharacterManager] IP-Adapter encoding failed: $e');
    }
    return null;
  }

  /// Get or create an embedding for a character from their references.
  ///
  /// Looks for existing embeddings first, then falls back to encoding
  /// the most recent reference image.
  Future<String?> getOrCreateEmbedding(CharacterDefinition char) async {
    final refs = await getReferences(char.id);
    if (refs.isEmpty) return null;

    // Look for existing embedding
    for (final ref in refs) {
      final embedding = ref['embedding'] as String?;
      if (embedding != null && embedding.isNotEmpty) {
        if (await File(embedding).exists()) return embedding;
      }
    }

    // Encode the most recent reference image
    final latestRef = refs.first;
    final imageBlob = latestRef['reference_image'] as List<int>?;
    if (imageBlob == null || imageBlob.isEmpty) return null;

    final imageBase64 = base64Encode(imageBlob);
    return await saveAndEncodeReference(
      characterId: char.id,
      name: char.name,
      imageBase64: imageBase64,
      visualDescription: char.visualDescription,
      defaultVoice: char.defaultVoice,
    );
  }

  /// Generate a character-consistent image using IP-Adapter.
  ///
  /// Uses the character's embedding to condition generation.
  Future<Map<String, dynamic>> generateConsistentImage({
    required CharacterDefinition character,
    required String prompt,
    String? negativePrompt,
    int width = 512,
    int height = 512,
    int steps = 30,
    double ipAdapterScale = 0.6,
  }) async {
    if (_localModelManager == null) {
      return {'success': false, 'error': 'No local model manager'};
    }

    // Get embedding
    final embeddingPath = await getOrCreateEmbedding(character);

    // Get reference image path
    String? referencePath;
    final refs = await getReferences(character.id);
    if (refs.isNotEmpty) {
      final imageBlob = refs.first['reference_image'] as List<int>?;
      if (imageBlob != null && imageBlob.isNotEmpty) {
        final home = Platform.environment['HOME'] ?? '/tmp';
        referencePath = '$home/.opencli/models/ip_adapter_face/references/ref_${character.id}_latest.png';
        await File(referencePath).writeAsBytes(imageBlob);
      }
    }

    if (embeddingPath == null && referencePath == null) {
      return {'success': false, 'error': 'No reference for character ${character.name}'};
    }

    try {
      final result = await _localModelManager!.runIPAdapter(
        action: 'generate_with_reference',
        params: {
          'embedding_path': embeddingPath,
          'reference_path': referencePath,
          'prompt': prompt,
          'negative_prompt': negativePrompt ?? 'low quality, blurry, bad anatomy',
          'width': width,
          'height': height,
          'steps': steps,
          'ip_adapter_scale': ipAdapterScale,
        },
      );

      return result.success
          ? {'success': true, 'image_base64': result.data['image_base64'], 'method': result.data['method']}
          : {'success': false, 'error': result.data['error'] ?? 'Generation failed'};
    } catch (e) {
      return {'success': false, 'error': 'IP-Adapter generation failed: $e'};
    }
  }

  /// Get all references for a character.
  Future<List<Map<String, dynamic>>> getReferences(String characterId) async {
    return await _db.db.query(
      'character_references',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at DESC',
    );
  }

  /// Get references for an episode.
  Future<List<Map<String, dynamic>>> getEpisodeReferences(String episodeId) async {
    return await _db.db.query(
      'character_references',
      where: 'episode_id = ?',
      whereArgs: [episodeId],
      orderBy: 'created_at DESC',
    );
  }

  /// Delete a character reference.
  Future<bool> deleteReference(String id) async {
    final count = await _db.db.delete(
      'character_references',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  /// Build an enhanced prompt with character visual descriptions for consistency.
  String buildConsistentPrompt(
    String basePrompt,
    List<CharacterDefinition> characters,
    List<String> characterIdsInScene,
  ) {
    final charDescriptions = characterIdsInScene
        .map((id) => characters.where((c) => c.id == id).firstOrNull)
        .where((c) => c != null && c.visualDescription.isNotEmpty)
        .map((c) => '${c!.name}: ${c.visualDescription}')
        .join('. ');

    if (charDescriptions.isEmpty) return basePrompt;

    return '$basePrompt. Characters present: $charDescriptions';
  }
}
