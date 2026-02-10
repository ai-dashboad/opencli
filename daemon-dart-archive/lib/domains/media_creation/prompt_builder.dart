/// Professional AI video prompt engineering system.
///
/// Supports multiple generation modes:
///   - Image-to-Video: animate a still photo with cinematic motion
///   - Text-to-Video: generate a full scene from a text description
///   - Multi-Scene: episodic content with scene decomposition
///   - Vertical Social: optimized for TikTok/Reels/Shorts (9:16)
///
/// Each preset covers:
///   - Camera movement and lens choice
///   - Lighting and color grading
///   - Motion dynamics and pacing
///   - Atmospheric elements and texture
///   - Post-production aesthetic
///
/// Compatible with: Sora, Runway Gen-4, Kling, Luma, Replicate, Pika

/// Style presets for AI video generation.
enum VideoStylePreset {
  cinematic,
  adPromo,
  socialMedia,
  calmAesthetic,
  epic,
  mysterious,
}

/// Generation mode determines prompt structure and output format.
enum VideoGenerationMode {
  /// Animate a still photo with cinematic motion (default)
  imageToVideo,

  /// Generate a full scene from a text description
  textToVideo,

  /// Multi-scene episodic content (3-5 min, scene-by-scene plan)
  multiScene,

  /// Short vertical video optimized for social media (9:16, 15-30s)
  verticalSocial,
}

/// Builds professional cinematic prompts from style presets, with
/// provider-specific adaptation for each AI video API.
///
/// Design principles (from production prompt engineering):
/// 1. Visual direction (camera, lighting, style)
/// 2. Narrative structure (beginning, development, climax, ending)
/// 3. Temporal control (scene duration, pacing)
/// 4. Constraints (consistency, no hallucinated elements)
///
/// AI acts as a **film director**, not a narrator.
class PromptBuilder {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Build a full cinematic prompt from a style preset.
  ///
  /// [mode] selects generation mode (image-to-video, text-to-video, etc).
  /// [userHint] appends additional user direction to the generated prompt.
  /// [subjectDescription] describes the subject/{subject} placeholder.
  /// [durationSeconds] target video duration (used for multi-scene planning).
  static String buildFromPreset(
    VideoStylePreset preset, {
    VideoGenerationMode mode = VideoGenerationMode.imageToVideo,
    String? userHint,
    String? subjectDescription,
    int? durationSeconds,
  }) {
    String base;
    switch (mode) {
      case VideoGenerationMode.imageToVideo:
        base = _imageToVideoPrompts[preset] ??
            _imageToVideoPrompts[VideoStylePreset.cinematic]!;
      case VideoGenerationMode.textToVideo:
        base = _textToVideoPrompts[preset] ??
            _textToVideoPrompts[VideoStylePreset.cinematic]!;
      case VideoGenerationMode.multiScene:
        base = _buildMultiScenePrompt(preset, durationSeconds ?? 60);
      case VideoGenerationMode.verticalSocial:
        base = _buildVerticalSocialPrompt(preset);
    }

    if (subjectDescription != null && subjectDescription.isNotEmpty) {
      base = base.replaceAll('{subject}', subjectDescription);
    } else {
      base = base.replaceAll('{subject}', 'the scene');
    }

    if (userHint != null && userHint.isNotEmpty) {
      return '$base Additional direction: $userHint';
    }
    return base;
  }

  /// Build a director-mode meta-prompt for agent pipeline use.
  ///
  /// This returns a system-level instruction for an AI agent that will
  /// decompose text/images into video generation tasks.
  static String buildDirectorPrompt({
    required String sourceText,
    VideoGenerationMode mode = VideoGenerationMode.textToVideo,
    VideoStylePreset style = VideoStylePreset.cinematic,
    int targetDurationSeconds = 30,
    String aspectRatio = '16:9',
  }) {
    final moodName = _styleToMood[style] ?? 'cinematic';
    return '''You are a cinematic video director AI.

Based on the following text, generate a short cinematic video.
The video should visually tell the story without narration, using strong imagery, camera movement, and atmosphere.

Text source:
"""
$sourceText
"""

Video requirements:
- Length: $targetDurationSeconds seconds
- Style: cinematic, high quality, realistic lighting
- Aspect ratio: $aspectRatio
- Frame rate: 24fps
- Mood: $moodName

Structure the video into clear scenes:
1. Opening scene: establish setting and mood
2. Development: show key events visually
3. Climax: emotional or dramatic peak
4. Ending: a strong visual conclusion

For each scene, describe:
- Camera angle and movement
- Main characters or subjects
- Environment and lighting
- Emotional tone

Do not include subtitles, captions, or on-screen text.
Focus on visual storytelling only.''';
  }

  /// Build a scene decomposition prompt for the agent pipeline.
  ///
  /// Step 1 of Version E: break input into visual scenes.
  static String buildSceneDecompositionPrompt(String sourceText) {
    return '''Analyze the input text and break it into visual scenes suitable for video generation.
Return structured scene descriptions only.

Input:
"""
$sourceText
"""

For each scene, provide:
- Scene number
- Duration (seconds)
- Visual description
- Camera movement
- Mood and pacing
- Transition to next scene

Ensure logical visual continuity between scenes.''';
  }

  /// Adapt a prompt for a specific provider's API format and strengths.
  static Map<String, dynamic> adaptForProvider(
    String providerId,
    String prompt, {
    int durationSeconds = 5,
    String? imageBase64,
    String? aspectRatio,
  }) {
    switch (providerId) {
      case 'replicate':
        return _adaptForReplicate(prompt, durationSeconds, aspectRatio);
      case 'runway':
        return _adaptForRunway(prompt, durationSeconds, aspectRatio);
      case 'kling':
        return _adaptForKling(prompt, durationSeconds, aspectRatio);
      case 'luma':
        return _adaptForLuma(prompt, durationSeconds, aspectRatio);
      default:
        return {'prompt': prompt, 'duration': durationSeconds};
    }
  }

  /// Parse a style name string into a preset enum.
  static VideoStylePreset parseStyle(String? style) {
    if (style == null) return VideoStylePreset.cinematic;
    for (final preset in VideoStylePreset.values) {
      if (preset.name.toLowerCase() == style.toLowerCase()) return preset;
    }
    return VideoStylePreset.cinematic;
  }

  /// Parse a mode name string into a generation mode enum.
  static VideoGenerationMode parseMode(String? mode) {
    if (mode == null) return VideoGenerationMode.imageToVideo;
    for (final m in VideoGenerationMode.values) {
      if (m.name.toLowerCase() == mode.toLowerCase()) return m;
    }
    return VideoGenerationMode.imageToVideo;
  }

  /// Get a short display description for a style preset.
  static String descriptionForPreset(VideoStylePreset preset) {
    return _styleDescriptions[preset] ?? 'Cinematic';
  }

  // ---------------------------------------------------------------------------
  // Image-to-Video Prompts (Version B) — animate a still photo
  // ---------------------------------------------------------------------------

  static const Map<VideoStylePreset, String> _imageToVideoPrompts = {
    VideoStylePreset.cinematic:
        'Using the provided image as the first frame and visual reference, '
            'create a cinematic video that expands the scene naturally. '
            'Cinematic slow dolly forward, shallow depth of field with anamorphic '
            'bokeh, dramatic volumetric lighting with warm golden rays cutting '
            'through atmosphere. Subtle film grain texture, rich teal-and-orange '
            'color grading. Bring {subject} to life with gentle organic motion — '
            'swaying foliage, drifting dust particles, subtle fabric movement. '
            'Smooth 24fps filmic motion blur, 2.39:1 widescreen composition. '
            'Start from the exact composition of the image. Introduce subtle motion, '
            'then slowly expand with gentle camera movement. '
            'Maintain consistency in characters, objects, and environment. '
            'Avoid sudden cuts.',
    VideoStylePreset.adPromo:
        'Using the provided image as the first frame and visual reference, '
            'create a professional commercial video. '
            'Dynamic product-hero reveal with smooth orbital camera tracking '
            '360-degree around {subject}. Bright clean key lighting with soft '
            'gradient shadows, modern minimalist studio backdrop. Professional '
            'commercial-grade motion with confident deliberate pacing. '
            'Slow-motion detail reveals at 120fps, premium reflective surfaces, '
            'sleek transitions between angles. High-end brand energy with '
            'razor-sharp focus on the subject, subtle environmental reflections, '
            'and polished post-production color science. '
            'Start from the exact image composition, then orbit smoothly.',
    VideoStylePreset.socialMedia:
        'Using the provided image as the first frame and visual reference, '
            'create a high-energy social media video. '
            'Fast-paced trendy motion with vibrant hyper-saturated colors and '
            'bold dynamic camera — quick snap zoom-ins, whip pans, smooth '
            'parallax tracking shots. High energy visual rhythm optimized for '
            'vertical 9:16 framing. Attention-grabbing hook animation in the '
            'first 0.5 seconds. {subject} moves with energetic purpose. '
            'Modern neon color palette, crisp ultra-sharp detail, punchy '
            'contrast with lifted shadows. TikTok/Reels ready aesthetic with '
            'seamless looping potential.',
    VideoStylePreset.calmAesthetic:
        'Using the provided image as the first frame and visual reference, '
            'create a serene, meditative video. '
            'Gentle ethereal slow zoom with soft golden hour backlighting, '
            'dreamy shallow depth of field creating beautiful circular bokeh. '
            'Warm pastel tones — soft amber, blush pink, lavender highlights. '
            'Serene peaceful atmosphere surrounding {subject}. '
            'Subtle floating particles catching light, gentle breeze rippling '
            'through fabric and foliage, calm water surface reflections. '
            'Meditative pacing with smooth ethereal camera glide, '
            'impressionist softness, ASMR-level visual tranquility. '
            'Start from the image, introduce subtle motion gradually.',
    VideoStylePreset.epic:
        'Using the provided image as the first frame and visual reference, '
            'create an awe-inspiring epic video. '
            'Sweeping ultra-wide establishing shot with dramatic cloudscape, '
            'powerful forward dolly push building intensity toward {subject}. '
            'Cinematic grand scale with vast atmospheric depth and parallax. '
            'Dramatic volumetric cloud movement, dynamic god-ray lighting shifts, '
            'intense golden-hour atmospheric haze. Heroic low-angle upward tilt '
            'revealing scale, awe-inspiring sense of grandeur. '
            'Hans Zimmer energy — deep bass rumble in the visual rhythm. '
            'IMAX-worthy composition, 2.76:1 ultra-widescreen framing.',
    VideoStylePreset.mysterious:
        'Using the provided image as the first frame and visual reference, '
            'create a suspenseful mysterious video. '
            'Slow deliberate push-in through layered shadows and dense '
            'atmospheric haze, {subject} emerging from darkness. Low-key '
            'dramatic chiaroscuro lighting with deep crushed blacks and '
            'isolated specular highlights. Dense volumetric fog with '
            'god-ray light shafts cutting through at oblique angles. '
            'Dark moody color grading — cold desaturated blue-green tones '
            'with occasional warm amber accent. Suspenseful building tension, '
            'revealing details gradually. Subtle unsettling camera drift '
            'with imperceptible Dutch angle rotation.',
  };

  // ---------------------------------------------------------------------------
  // Text-to-Video Prompts (Version A) — generate full scenes
  // ---------------------------------------------------------------------------

  static const Map<VideoStylePreset, String> _textToVideoPrompts = {
    VideoStylePreset.cinematic:
        'A cinematic scene of {subject}. Shot on 35mm anamorphic lens with '
            'shallow depth of field. Dramatic natural lighting with volumetric '
            'rays, subtle film grain and halation. Rich teal-and-orange color '
            'grading with warm highlights and deep shadows. Slow deliberate '
            'camera dolly with subtle parallax. 24fps filmic motion blur, '
            'professional cinematography. The atmosphere feels alive with '
            'floating dust particles and organic ambient motion. '
            'Structure: opening establishes mood, development shows key visuals, '
            'ending delivers a strong visual conclusion. No text overlays.',
    VideoStylePreset.adPromo:
        'Professional commercial of {subject}. Clean studio lighting with '
            'soft key light and rim highlight separation. Smooth 360-degree '
            'orbit camera revealing every angle. Premium product photography '
            'aesthetic — sharp focus, pristine surfaces, controlled reflections. '
            'Modern minimalist composition with negative space. Slow-motion '
            'detail reveals, confident brand energy, polished color science '
            'with neutral whites and subtle warm accents. '
            'Visual storytelling only — no text, no voice-over.',
    VideoStylePreset.socialMedia:
        'Viral social media video of {subject}. Vertical 9:16 composition, '
            'vibrant saturated colors, bold fast camera movements — snap zooms, '
            'whip pans, dynamic parallax. Eye-catching hook in the first frame. '
            'High energy with punchy contrast, neon accent colors, ultra-sharp '
            'detail. Trendy modern aesthetic with seamless loop potential. '
            'Optimized for maximum engagement — every frame is scroll-stopping. '
            'Strong visual hook in first 3 seconds. No text overlays.',
    VideoStylePreset.calmAesthetic:
        'A serene scene of {subject} bathed in soft golden hour light. '
            'Gentle camera glide with dreamy shallow depth of field creating '
            'beautiful circular bokeh. Warm pastel tones — amber, blush, '
            'lavender. Floating dust motes catching light, subtle breeze '
            'through foliage. Meditative slow pacing, impressionist softness, '
            'ASMR visual tranquility. Everything feels warm, safe, ethereal. '
            'Visual storytelling only.',
    VideoStylePreset.epic:
        'An epic sweeping vista of {subject}. Ultra-wide establishing shot '
            'with dramatic cloudscape and volumetric god-rays. Powerful forward '
            'camera push with vast atmospheric depth and parallax layers. '
            'Dramatic lighting shifts, golden hour warmth against storm clouds. '
            'Heroic low-angle composition revealing massive scale. IMAX-worthy '
            'framing with 2.76:1 aspect ratio energy. The scene commands awe. '
            'Visual storytelling only — no narration.',
    VideoStylePreset.mysterious:
        'A mysterious scene revealing {subject} through dense fog and '
            'layered shadows. Low-key chiaroscuro lighting — deep blacks with '
            'isolated specular highlights. Volumetric haze with oblique light '
            'shafts. Cold desaturated blue-green tones with occasional amber '
            'accent. Slow push-in building suspense, details emerging gradually. '
            'Subtle camera drift with imperceptible Dutch angle. '
            'Noir atmosphere, every shadow tells a story. No text overlays.',
  };

  // ---------------------------------------------------------------------------
  // Multi-Scene Prompts (Version C) — episodic content, 3-5 min
  // ---------------------------------------------------------------------------

  static String _buildMultiScenePrompt(
      VideoStylePreset preset, int totalDuration) {
    final mood = _styleToMood[preset] ?? 'cinematic';
    return '''Create a multi-scene cinematic video of {subject}.

Total length: $totalDuration seconds.
Visual style: ${preset.name}, consistent color grading throughout.
Aspect ratio: 16:9. No dialogue, narration, or subtitles. Visual storytelling only.
Mood: $mood.

Structure into clear scenes:
Scene 1 (Opening): Establish setting and mood. Slow, atmospheric introduction.
Scene 2 (Development): Show key visual events. Build narrative momentum.
Scene 3 (Climax): Emotional or dramatic peak. Most dynamic camera work.
Scene 4 (Resolution): Strong visual conclusion. Satisfying final image.

Each scene must have:
- Consistent characters and environments
- Logical visual continuity
- Smooth transitions between scenes
- Camera movement appropriate to the ${preset.name} style

${_presetCameraGuidance[preset] ?? ''}''';
  }

  // ---------------------------------------------------------------------------
  // Vertical Social Prompts (Version D) — TikTok/Reels/Shorts
  // ---------------------------------------------------------------------------

  static String _buildVerticalSocialPrompt(VideoStylePreset preset) {
    final mood = _styleToMood[preset] ?? 'energetic';
    return '''Create a short vertical cinematic video of {subject}.

Requirements:
- Length: 15-30 seconds
- Aspect ratio: 9:16 (vertical, optimized for mobile)
- Strong visual hook in the first 3 seconds
- Fast pacing with cinematic quality
- Mood: $mood

Structure:
- Hook (0-3s): Visually striking moment that stops the scroll
- Development (3-20s): Story progression with ${preset.name} visual style
- Ending (last 3-5s): Impactful final image, seamless loop potential

No text overlays. No voice-over. Only visual storytelling.
${_presetCameraGuidance[preset] ?? ''}''';
  }

  // ---------------------------------------------------------------------------
  // Style Metadata
  // ---------------------------------------------------------------------------

  static const Map<VideoStylePreset, String> _styleDescriptions = {
    VideoStylePreset.cinematic:
        'Dramatic lighting, anamorphic bokeh, film grain',
    VideoStylePreset.adPromo: 'Studio orbit, commercial polish, brand energy',
    VideoStylePreset.socialMedia: 'Fast-paced, vertical-first, scroll-stopping',
    VideoStylePreset.calmAesthetic:
        'Golden hour, dreamy bokeh, meditative calm',
    VideoStylePreset.epic: 'Vast scale, dramatic sky, IMAX grandeur',
    VideoStylePreset.mysterious: 'Noir shadows, fog & haze, building tension',
  };

  static const Map<VideoStylePreset, String> _styleToMood = {
    VideoStylePreset.cinematic: 'dramatic, emotional',
    VideoStylePreset.adPromo: 'confident, premium, polished',
    VideoStylePreset.socialMedia: 'energetic, vibrant, trendy',
    VideoStylePreset.calmAesthetic: 'serene, dreamy, peaceful',
    VideoStylePreset.epic: 'awe-inspiring, powerful, grand',
    VideoStylePreset.mysterious: 'suspenseful, dark, enigmatic',
  };

  static const Map<VideoStylePreset, String> _presetCameraGuidance = {
    VideoStylePreset.cinematic:
        'Camera: Slow dolly, rack focus, shallow DOF, anamorphic lens. '
            'Lighting: Volumetric rays, teal-orange grade, film grain.',
    VideoStylePreset.adPromo:
        'Camera: Smooth orbit, detail reveals, clean angles. '
            'Lighting: Bright studio key light, rim separation, pristine.',
    VideoStylePreset.socialMedia:
        'Camera: Snap zooms, whip pans, dynamic parallax. '
            'Lighting: Vibrant neon, punchy contrast, saturated.',
    VideoStylePreset.calmAesthetic:
        'Camera: Gentle glide, slow zoom, ethereal drift. '
            'Lighting: Golden hour, pastel tones, soft bokeh.',
    VideoStylePreset.epic:
        'Camera: Ultra-wide sweep, low-angle tilt, forward push. '
            'Lighting: God-rays, storm clouds, dramatic shifts.',
    VideoStylePreset.mysterious:
        'Camera: Slow push-in, Dutch angle drift, reveal through fog. '
            'Lighting: Chiaroscuro, cold blue-green, isolated highlights.',
  };

  // ---------------------------------------------------------------------------
  // Provider-Specific Adaptation
  // ---------------------------------------------------------------------------

  /// Replicate (Kling v2.6): Concise motion-focused prompts, ~450 chars.
  static Map<String, dynamic> _adaptForReplicate(
    String prompt,
    int duration,
    String? aspectRatio,
  ) {
    return {
      'prompt': _truncateToTokens(prompt, 450),
      'duration': '$duration',
      if (aspectRatio != null) 'aspect_ratio': aspectRatio,
    };
  }

  /// Runway Gen-4: Detailed camera direction, ~800 chars.
  static Map<String, dynamic> _adaptForRunway(
    String prompt,
    int duration,
    String? aspectRatio,
  ) {
    return {
      'prompt': _truncateToTokens(prompt, 800),
      'duration': duration.clamp(5, 10),
      'ratio': aspectRatio ?? '16:9',
    };
  }

  /// Kling AI (PiAPI): Motion-control keywords + negative prompt, ~500 chars.
  static Map<String, dynamic> _adaptForKling(
    String prompt,
    int duration,
    String? aspectRatio,
  ) {
    return {
      'prompt': _truncateToTokens(prompt, 500),
      'negative_prompt':
          'low quality, blurry, distorted, watermark, text overlay, '
              'static image, no motion, jerky movement, artifacts',
      'duration': duration.clamp(5, 10),
      'aspect_ratio': aspectRatio ?? '16:9',
    };
  }

  /// Luma Dream Machine: Natural language, no jargon, ~600 chars.
  static Map<String, dynamic> _adaptForLuma(
    String prompt,
    int duration,
    String? aspectRatio,
  ) {
    var adapted = prompt
        .replaceAll(RegExp(r'\b\d+fps\b'), '')
        .replaceAll(RegExp(r'\b\d+:\d+\s*(?:aspect|widescreen|framing)\b'), '')
        .trim();
    adapted = _truncateToTokens(adapted, 600);
    return {
      'prompt': adapted,
      'aspect_ratio': aspectRatio ?? '16:9',
      'loop': false,
    };
  }

  // ---------------------------------------------------------------------------
  // Advanced Agent Pipeline Prompts (Version E)
  // ---------------------------------------------------------------------------

  /// Build a validation-focused generation prompt.
  ///
  /// Ensures the AI strictly follows the source text without hallucinating
  /// new characters, locations, objects, or events.
  static String buildValidationPrompt(String sourceText) {
    return '''You are a validation-focused video generator.

Create a video strictly based on the text below.
Do not introduce any new characters, locations, objects, or events that are not explicitly described.

Text:
"""
$sourceText
"""

Before generating the video, verify internally that:
- No additional characters are added
- No new locations appear
- No events beyond the text occur

Generate the video description only.''';
  }

  /// Build a character-consistent generation prompt.
  ///
  /// Ensures a single character remains visually consistent across all scenes.
  static String buildCharacterConsistentPrompt({
    required String characterDescription,
    required String sceneDescription,
    int durationSeconds = 45,
    VideoStylePreset style = VideoStylePreset.cinematic,
  }) {
    return '''Create a cinematic video with a single main character.

Character definition:
$characterDescription

Ensure the character remains visually consistent across all scenes.
Do not change clothing, age, or physical features.

Scene:
$sceneDescription

Video length: $durationSeconds seconds
Style: ${style.name} realism
Mood: ${_styleToMood[style] ?? 'cinematic'}

${_presetCameraGuidance[style] ?? ''}''';
  }

  /// Build a storyboard breakdown prompt from narrative text.
  ///
  /// Returns a structured scene-by-scene plan without generating video.
  static String buildStoryboardPrompt(String narrativeText) {
    return '''You are a storyboard director AI.

Break the following text into visual scenes suitable for a cinematic video.

Text:
"""
$narrativeText
"""

Output for each scene:
- Scene number
- Duration (seconds)
- Visual description
- Camera movement
- Mood and pacing
- Transition to next scene

Do not generate video yet.
Only output the scene breakdown.
Ensure logical visual continuity between scenes.''';
  }

  // ---------------------------------------------------------------------------
  // Production-Grade Cinematic Prompt
  // ---------------------------------------------------------------------------

  /// Build a production-grade cinematic video prompt.
  ///
  /// Combines strict input adherence, narrative structure, character consistency,
  /// safety rules, image-to-video best practices, and pre-generation validation
  /// into a single comprehensive prompt suitable for professional use.
  static String buildProductionPrompt({
    required String inputText,
    bool hasImage = false,
    int durationSeconds = 30,
    String aspectRatio = '16:9',
    VideoStylePreset style = VideoStylePreset.cinematic,
  }) {
    final mood = _styleToMood[style] ?? 'cinematic';
    final camera =
        _presetCameraGuidance[style] ?? 'Smooth, intentional camera movement.';

    // Compute narrative timing splits (20% / 50% / 20% / 10%)
    final t1 = (durationSeconds * 0.20).round();
    final t2 = (durationSeconds * 0.70).round();
    final t3 = (durationSeconds * 0.90).round();

    final imageRules = hasImage
        ? '''
Image-to-Video Rules (image is provided):
- The image defines the initial frame, characters, and environment
- Do not change character appearance or add new objects not in the image
- Introduce only subtle, realistic motion
- Expand the scene gradually with camera movement
'''
        : '';

    return '''You are a professional cinematic video generation AI operating in a production environment.

Generate a cinematic video strictly based on the following input.
Do not add, assume, or hallucinate any elements that are not explicitly implied by the input.

Input:
"""
$inputText
"""

Video Requirements:
- Length: $durationSeconds seconds
- Aspect ratio: $aspectRatio
- Frame rate: 24fps
- Visual style: ${style.name} realism
- Lighting: natural and consistent
- Camera: $camera
- No subtitles, captions, or on-screen text
- No voice-over or narration
- Visual storytelling only

Narrative Structure:
1. Opening (0-${t1}s): establish environment and mood ($mood)
2. Development (${t1}-${t2}s): visual progression based on the input
3. Climax (${t2}-${t3}s): emotional or visual peak (if applicable)
4. Ending (${t3}-${durationSeconds}s): a clear and visually satisfying conclusion

Consistency Rules:
- Characters must remain visually consistent across all scenes
- Environments must not change abruptly
- Lighting and time of day must transition naturally
- No sudden cuts, flickering, or style changes

$imageRules
Safety & Compliance Rules:
- No violence
- No explicit or sexual content
- No identifiable real people
- No copyrighted characters or brands
- No illegal or harmful activities

Abstract Text Handling:
- If the input is abstract or emotional, express it using environment, light, motion, and atmosphere
- Do not use literal symbols or on-screen text to explain concepts

Validation Requirement:
Before generating the video, internally verify that:
- All scenes are derived from the input
- No rules are violated
- Visual continuity and style consistency are preserved

If any rule cannot be satisfied, stop and report the issue instead of generating the video.''';
  }

  // ---------------------------------------------------------------------------
  // Business Scenario Prompts
  // ---------------------------------------------------------------------------

  /// Build a product promo video prompt.
  ///
  /// Generates a professional product showcase video with studio lighting,
  /// smooth camera orbits, and clean composition.
  static String buildProductPromoPrompt({
    required String productName,
    String? productDescription,
    String aspectRatio = '16:9',
    int durationSeconds = 15,
    String style = 'professional', // professional, luxury, energetic, minimal
  }) {
    final orientation = aspectRatio == '9:16'
        ? 'vertical (9:16, mobile-first)'
        : aspectRatio == '1:1'
            ? 'square (1:1, feed-optimized)'
            : 'horizontal (16:9, widescreen)';

    final styleGuide = switch (style) {
      'luxury' =>
        'Dark matte background, warm golden rim lighting, slow elegant camera orbit. '
            'Premium feel with deep shadows, selective focus, and reflective surfaces. '
            'Color grade: rich blacks, warm gold highlights, subtle amber accents.',
      'energetic' =>
        'Bright gradient background, dynamic camera angles with quick cuts between details. '
            'Vibrant saturated colors, bold contrast, fast-paced energy. '
            'Punchy transitions, multiple angles in rapid succession.',
      'minimal' =>
        'Pure white background, soft even lighting, minimal shadows. '
            'Clean negative space, centered composition, zen-like simplicity. '
            'Gentle slow zoom, muted color palette, elegant restraint.',
      _ => 'Clean studio background, professional 3-point lighting setup. '
          'Smooth 360-degree orbit revealing all angles of the product. '
          'Crisp sharp focus, neutral color science, commercial polish.',
    };

    final desc = productDescription != null
        ? '\nProduct description: $productDescription'
        : '';

    return '''Product showcase video for "$productName".$desc

Orientation: $orientation
Duration: $durationSeconds seconds
Style: $styleGuide

Structure:
1. Hero reveal (0-${(durationSeconds * 0.25).round()}s): Product enters frame or emerges from shadow. Clean, impactful first impression.
2. Detail showcase (${(durationSeconds * 0.25).round()}-${(durationSeconds * 0.75).round()}s): Camera orbits slowly, highlighting key features and textures. Smooth dolly and rack focus.
3. Final hero shot (${(durationSeconds * 0.75).round()}-${durationSeconds}s): Pull back to full product view. Strong, memorable closing composition.

Rules:
- Camera orbits smoothly around the product
- Focus on textures, materials, and craftsmanship
- No text overlays, watermarks, or logos
- No human hands or models unless implied
- Studio-quality lighting, no harsh shadows
- Product must remain the sole visual focus''';
  }

  /// Build a portrait effects prompt for social media (TikTok/Douyin).
  ///
  /// Creates dramatic portrait videos with cinematic effects,
  /// optimized for vertical mobile viewing.
  static String buildPortraitEffectPrompt({
    String effect = 'cinematic_zoom',
    String aspectRatio = '9:16',
    int durationSeconds = 10,
  }) {
    final effectGuide = switch (effect) {
      'dramatic_light' => 'Dramatic studio lighting shifting across the face. '
          'Start with rim lighting silhouette, transition to key light reveal. '
          'Volumetric light rays, lens flares, chiaroscuro contrast.',
      'pulse_glow' => 'Rhythmic pulsing light effect surrounding the subject. '
          'Soft glow builds and fades in 2-second cycles. '
          'Warm golden pulses with cool blue undertones between beats.',
      'slow_orbit' => 'Camera slowly orbits around the subject at eye level. '
          'Shallow depth of field, background blur shifts with parallax. '
          'Consistent dramatic lighting tracks with the orbit.',
      _ => 'Slow cinematic push-in from medium shot to close-up. '
          'Shallow depth of field with beautiful bokeh. '
          'Face stays in sharp focus, background softens progressively.',
    };

    final orientation = aspectRatio == '9:16'
        ? 'Vertical 9:16 (TikTok/Douyin/Reels)'
        : 'Square 1:1 (Instagram feed)';

    return '''Portrait video with ${effect.replaceAll('_', ' ')} effect.

Orientation: $orientation
Duration: $durationSeconds seconds
Effect: $effectGuide

Portrait rules:
- Subject's face must remain sharp and consistent throughout
- Preserve skin tones and natural features
- No distortion or morphing of facial features
- Dramatic but flattering lighting
- Background is secondary — soft, out of focus
- Vertical composition: face centered in upper third
- Cinematic 24fps motion, smooth and professional

Visual storytelling:
- Opening: establish the subject with the effect building
- Middle: full effect in motion, most visually striking moment
- Ending: graceful wind-down, memorable final frame''';
  }

  /// Build a novel-to-anime/cinematic video prompt.
  ///
  /// Decomposes narrative text into visual scenes and generates
  /// anime/manga/cinematic style video direction.
  static String buildNovelToAnimePrompt({
    required String novelText,
    String animeStyle = 'anime', // anime, manga, cinematic
    int durationSeconds = 30,
  }) {
    final styleGuide = switch (animeStyle) {
      'manga' =>
        'Black and white manga art style with bold ink lines, screentone shading, '
            'dramatic panel-style composition. Speed lines for action, floating particles for emotion. '
            'High contrast, expressive character poses, Japanese manga aesthetics.',
      'cinematic' =>
        'Photorealistic cinematic rendering with anime-inspired camera work. '
            'Dramatic lighting, shallow depth of field, lens flares. '
            'Real-world environments with stylized character designs.',
      _ => 'Japanese anime cel-shading style with vibrant saturated colors. '
          'Clean line art, expressive character animation, dynamic camera angles. '
          'Studio Ghibli-inspired environmental detail, Makoto Shinkai lighting.',
    };

    // Compute narrative timing
    final t1 = (durationSeconds * 0.15).round();
    final t2 = (durationSeconds * 0.65).round();
    final t3 = (durationSeconds * 0.85).round();

    return '''Adapt the following text into a visual $animeStyle video.

Text:
"""
$novelText
"""

Visual style: $styleGuide
Duration: $durationSeconds seconds
Aspect ratio: 16:9

Narrative structure:
1. Setting (0-${t1}s): Establish the world, environment, and atmosphere from the text.
2. Story (${t1}-${t2}s): Visualize the key events and character actions described.
3. Climax (${t2}-${t3}s): The most dramatic or emotional moment in the passage.
4. Resolution (${t3}-${durationSeconds}s): A concluding visual that captures the text's essence.

Adaptation rules:
- Only visualize what is described or directly implied in the text
- Characters must remain visually consistent across all scenes
- Environments must match the text's descriptions
- Do not add characters, objects, or events not in the source text
- Express emotions through visual metaphor (weather, lighting, color)
- No dialogue text, subtitles, or narration overlays

Camera and motion:
- Anime-style camera: dramatic zooms, slow pans across environments
- Character close-ups for emotional moments
- Wide establishing shots for world-building
- Smooth transitions between scenes (dissolve, pan, or light-based)''';
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  /// Truncate at sentence boundaries, never mid-word.
  static String _truncateToTokens(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    final truncated = text.substring(0, maxChars);
    final lastPeriod = truncated.lastIndexOf('. ');
    if (lastPeriod > maxChars * 0.6) {
      return truncated.substring(0, lastPeriod + 1);
    }
    final lastComma = truncated.lastIndexOf(', ');
    if (lastComma > maxChars * 0.7) {
      return truncated.substring(0, lastComma + 1);
    }
    return truncated;
  }
}
