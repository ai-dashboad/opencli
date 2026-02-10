import '../pipeline/pipeline_definition.dart';
import 'episode_script.dart';

/// Converts an EpisodeScript into a PipelineDefinition.
///
/// This allows episode generation to leverage the existing pipeline
/// execution infrastructure (parallelism, progress, retry).
class EpisodePipelineBuilder {
  /// Build a pipeline from an episode script.
  static PipelineDefinition build(EpisodeScript script) {
    final nodes = <PipelineNode>[];
    final edges = <PipelineEdge>[];

    double yOffset = 0;
    const xImage = 100.0;
    const xVideo = 400.0;
    const xTTS = 700.0;
    const xAssemble = 1000.0;
    const xFinal = 1300.0;
    const rowHeight = 150.0;

    // Create per-scene nodes
    for (int i = 0; i < script.scenes.length; i++) {
      final scene = script.scenes[i];
      final sceneY = yOffset + i * rowHeight;

      // Image generation node
      final imgNode = PipelineNode(
        id: 'img_$i',
        type: 'media_ai_generate_image',
        domain: 'media_creation',
        label: 'Scene ${i + 1} Image',
        x: xImage,
        y: sceneY,
        params: {
          'prompt': scene.visualDescription,
          'style': 'anime',
          'aspect_ratio': '16:9',
          'provider': 'pollinations',
        },
      );
      nodes.add(imgNode);

      // Video generation node
      final vidNode = PipelineNode(
        id: 'vid_$i',
        type: 'media_ai_generate_video',
        domain: 'media_creation',
        label: 'Scene ${i + 1} Video',
        x: xVideo,
        y: sceneY,
        params: {
          'custom_prompt': scene.visualDescription,
          'style': 'cinematic',
          'duration': scene.videoDurationSeconds,
          'image_base64': '{{img_$i.image_base64}}',
        },
      );
      nodes.add(vidNode);

      // TTS node (if scene has dialogue)
      if (scene.dialogue.isNotEmpty) {
        final dialogueText = scene.dialogue.map((d) => d.text).join('\n');
        final ttsNode = PipelineNode(
          id: 'tts_$i',
          type: 'media_tts_synthesize',
          domain: 'media_creation',
          label: 'Scene ${i + 1} Voice',
          x: xTTS,
          y: sceneY,
          params: {
            'text': dialogueText,
            'voice': scene.dialogue.first.voice ?? 'zh-CN-XiaoxiaoNeural',
          },
        );
        nodes.add(ttsNode);
      }

      // Assembly node
      final assemblyNode = PipelineNode(
        id: 'assemble_$i',
        type: 'media_video_assembly',
        domain: 'media_creation',
        label: 'Scene ${i + 1} Assembly',
        x: xAssemble,
        y: sceneY,
        params: {
          'video_base64': '{{vid_$i.video_base64}}',
          if (scene.dialogue.isNotEmpty)
            'audio_base64': '{{tts_$i.audio_base64}}',
        },
      );
      nodes.add(assemblyNode);

      // Edges: img → vid, vid → assemble, tts → assemble
      edges.add(PipelineEdge(
        id: 'e_img_vid_$i',
        sourceNode: 'img_$i',
        sourcePort: 'output',
        targetNode: 'vid_$i',
        targetPort: 'input',
      ));
      edges.add(PipelineEdge(
        id: 'e_vid_asm_$i',
        sourceNode: 'vid_$i',
        sourcePort: 'output',
        targetNode: 'assemble_$i',
        targetPort: 'input',
      ));
      if (scene.dialogue.isNotEmpty) {
        edges.add(PipelineEdge(
          id: 'e_tts_asm_$i',
          sourceNode: 'tts_$i',
          sourcePort: 'output',
          targetNode: 'assemble_$i',
          targetPort: 'input',
        ));
      }
    }

    // Final output node
    final outputNode = PipelineNode(
      id: 'final_output',
      type: 'output',
      domain: 'system',
      label: 'Final Episode',
      x: xFinal,
      y: yOffset + (script.scenes.length / 2) * rowHeight,
      params: {
        'format': 'mp4',
        'save_path': '~/.opencli/episodes/${script.id}/${script.id}_final.mp4',
      },
    );
    nodes.add(outputNode);

    // Connect all assembly nodes to final output
    for (int i = 0; i < script.scenes.length; i++) {
      edges.add(PipelineEdge(
        id: 'e_asm_out_$i',
        sourceNode: 'assemble_$i',
        sourcePort: 'output',
        targetNode: 'final_output',
        targetPort: 'input',
      ));
    }

    return PipelineDefinition(
      id: 'episode_${script.id}',
      name: 'Episode: ${script.title}',
      description: 'Auto-generated pipeline for episode "${script.title}"',
      nodes: nodes,
      edges: edges,
      parameters: [],
    );
  }
}
