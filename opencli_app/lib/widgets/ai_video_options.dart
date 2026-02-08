import 'package:flutter/material.dart';

/// Callback when user confirms video generation.
typedef OnAIVideoGenerate = void Function({
  required String provider,
  required String style,
  String? customPrompt,
  String? scenario,
  String? aspectRatio,
  String? inputText,
  String? productName,
  int? duration,
  String? mode,
  String? effect,
});

/// Bottom sheet for selecting AI video generation options.
/// Supports 4 scenarios: product promo, portrait effects, novel-to-anime, custom.
class AIVideoOptionsSheet extends StatefulWidget {
  final OnAIVideoGenerate onGenerate;

  const AIVideoOptionsSheet({super.key, required this.onGenerate});

  @override
  State<AIVideoOptionsSheet> createState() => _AIVideoOptionsSheetState();
}

class _AIVideoOptionsSheetState extends State<AIVideoOptionsSheet> {
  String? _selectedScenario;

  // Product promo state
  String _productPlatform = '9:16';
  String _productStyle = 'professional';
  final _productNameCtrl = TextEditingController();
  final _productDescCtrl = TextEditingController();

  // Portrait state
  String _portraitEffect = 'cinematic_zoom';
  String _portraitPlatform = '9:16';
  int _portraitDuration = 5;

  // Novel state
  final _novelTextCtrl = TextEditingController();
  String _novelStyle = 'anime';
  int _novelDuration = 30;

  // Custom state
  String _customProvider = 'replicate';
  String _customStyle = 'cinematic';
  final _customPromptCtrl = TextEditingController();
  bool _customAdvanced = false;

  @override
  void dispose() {
    _productNameCtrl.dispose();
    _productDescCtrl.dispose();
    _novelTextCtrl.dispose();
    _customPromptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Back + Title
            Row(
              children: [
                if (_selectedScenario != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => setState(() => _selectedScenario = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                  ),
                Text(
                  _selectedScenario == null ? 'Create Video' : _scenarioTitle(),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedScenario == null)
              _buildScenarioGrid(theme)
            else if (_selectedScenario == 'product')
              _buildProductFlow(theme)
            else if (_selectedScenario == 'portrait')
              _buildPortraitFlow(theme)
            else if (_selectedScenario == 'novel')
              _buildNovelFlow(theme)
            else
              _buildCustomFlow(theme),
          ],
        ),
      ),
    );
  }

  String _scenarioTitle() => switch (_selectedScenario) {
    'product'  => 'Product Promo',
    'portrait' => 'Portrait Effects',
    'novel'    => 'Story to Video',
    'custom'   => 'Custom Video',
    _          => 'Create Video',
  };

  // ── Scenario Grid ──────────────────────────────────────────────────────────

  Widget _buildScenarioGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _scenarioCard(theme, 'product', Icons.shopping_bag, 'Product Promo',
            'E-commerce ads, product showcase', const Color(0xFFFF6D00)),
        _scenarioCard(theme, 'portrait', Icons.face_retouching_natural, 'Portrait Effects',
            'TikTok, Douyin, Instagram', const Color(0xFFE91E63)),
        _scenarioCard(theme, 'novel', Icons.auto_stories, 'Story to Video',
            'Novel to anime / cinematic', const Color(0xFF7C4DFF)),
        _scenarioCard(theme, 'custom', Icons.tune, 'Custom',
            'Provider, style, prompt', Colors.blueGrey),
      ],
    );
  }

  Widget _scenarioCard(ThemeData theme, String id, IconData icon, String title,
      String subtitle, Color color) {
    return GestureDetector(
      onTap: () => setState(() => _selectedScenario = id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── Product Promo Flow ─────────────────────────────────────────────────────

  Widget _buildProductFlow(ThemeData theme) {
    const platforms = [
      ('9:16', 'TikTok / Douyin', Icons.phone_android),
      ('1:1', 'Instagram', Icons.crop_square),
      ('16:9', 'YouTube', Icons.tv),
    ];
    const styles = [
      ('professional', 'Professional', 'Clean studio lighting'),
      ('luxury', 'Luxury', 'Dark background, golden accents'),
      ('energetic', 'Energetic', 'Dynamic angles, bright colors'),
      ('minimal', 'Minimal', 'Simple, elegant, white space'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product name
        TextField(
          controller: _productNameCtrl,
          decoration: InputDecoration(
            labelText: 'Product Name',
            hintText: 'e.g. Wireless Earbuds Pro',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        // Description (optional)
        TextField(
          controller: _productDescCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            hintText: 'Key features to highlight...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        // Platform
        Text('Platform', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildChipRow<String>(
          items: platforms.map((p) => (p.$1, p.$2, p.$3)).toList(),
          selected: _productPlatform,
          onSelected: (v) => setState(() => _productPlatform = v),
          theme: theme,
        ),
        const SizedBox(height: 16),
        // Style
        Text('Style', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: styles.map((s) {
            final selected = _productStyle == s.$1;
            return GestureDetector(
              onTap: () => setState(() => _productStyle = s.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                ),
                child: Column(
                  children: [
                    Text(s.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: selected ? theme.colorScheme.primary : null)),
                    Text(s.$3, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _generateButton(theme, 'Generate Product Video', Icons.shopping_bag, const Color(0xFFFF6D00)),
      ],
    );
  }

  // ── Portrait Effects Flow ──────────────────────────────────────────────────

  Widget _buildPortraitFlow(ThemeData theme) {
    const effects = [
      ('cinematic_zoom', 'Cinematic Zoom', Icons.zoom_in),
      ('dramatic_light', 'Dramatic Light', Icons.wb_incandescent),
      ('pulse_glow', 'Pulse Glow', Icons.favorite),
      ('slow_orbit', 'Slow Orbit', Icons.threesixty),
    ];
    const platforms = [
      ('9:16', 'TikTok / Douyin', Icons.phone_android),
      ('1:1', 'Instagram', Icons.crop_square),
    ];
    const durations = [5, 10, 15];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Effect
        Text('Effect', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: effects.map((e) {
            final selected = _portraitEffect == e.$1;
            return GestureDetector(
              onTap: () => setState(() => _portraitEffect = e.$1),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE91E63).withOpacity(0.15) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: const Color(0xFFE91E63), width: 2) : null,
                ),
                child: Row(
                  children: [
                    Icon(e.$3, size: 20, color: selected ? const Color(0xFFE91E63) : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(e.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: selected ? const Color(0xFFE91E63) : null)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Duration
        Text('Duration', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: durations.map((d) {
            final selected = _portraitDuration == d;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${d}s'),
                selected: selected,
                onSelected: (_) => setState(() => _portraitDuration = d),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Platform
        Text('Platform', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildChipRow<String>(
          items: platforms.map((p) => (p.$1, p.$2, p.$3)).toList(),
          selected: _portraitPlatform,
          onSelected: (v) => setState(() => _portraitPlatform = v),
          theme: theme,
        ),
        const SizedBox(height: 20),
        _generateButton(theme, 'Create Portrait Video', Icons.face_retouching_natural, const Color(0xFFE91E63)),
      ],
    );
  }

  // ── Novel to Anime Flow ────────────────────────────────────────────────────

  Widget _buildNovelFlow(ThemeData theme) {
    const styles = [
      ('anime', 'Anime', 'Japanese animation style'),
      ('manga', 'Manga', 'Black & white manga panels'),
      ('cinematic', 'Cinematic', 'Live-action realism'),
    ];
    const durations = [15, 30, 60];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text input
        TextField(
          controller: _novelTextCtrl,
          maxLines: 5,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: 'Novel / Story Text',
            hintText: 'Paste your story excerpt here...\n\ne.g. The young swordsman stood at the edge of the cliff, staring at the burning city below...',
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(14),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        // Style
        Text('Visual Style', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: styles.map((s) {
            final selected = _novelStyle == s.$1;
            return GestureDetector(
              onTap: () => setState(() => _novelStyle = s.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF7C4DFF).withOpacity(0.15) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: const Color(0xFF7C4DFF), width: 2) : null,
                ),
                child: Column(
                  children: [
                    Text(s.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: selected ? const Color(0xFF7C4DFF) : null)),
                    Text(s.$3, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Duration
        Text('Duration', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: durations.map((d) {
            final selected = _novelDuration == d;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${d}s'),
                selected: selected,
                onSelected: (_) => setState(() => _novelDuration = d),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _generateButton(theme, 'Generate Video from Story', Icons.auto_stories, const Color(0xFF7C4DFF)),
      ],
    );
  }

  // ── Custom Flow (original) ─────────────────────────────────────────────────

  Widget _buildCustomFlow(ThemeData theme) {
    const providers = [
      ('local', 'Local FFmpeg', 'Free', Icons.computer),
      ('replicate', 'Replicate', '~\$0.28', Icons.cloud),
      ('runway', 'Runway Gen-4', '~\$0.75', Icons.movie_filter),
      ('kling', 'Kling AI', '~\$0.90', Icons.auto_awesome_motion),
      ('luma', 'Luma Dream', '~\$0.20', Icons.blur_on),
    ];
    const styles = [
      ('cinematic', 'Cinematic', Icons.movie_creation),
      ('adPromo', 'Ad / Promo', Icons.campaign),
      ('socialMedia', 'Social', Icons.phone_android),
      ('calmAesthetic', 'Calm', Icons.spa),
      ('epic', 'Epic', Icons.landscape),
      ('mysterious', 'Mysterious', Icons.visibility),
    ];
    final isLocal = _customProvider == 'local';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provider
        Text('Provider', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = providers[i];
              final selected = _customProvider == p.$1;
              return GestureDetector(
                onTap: () => setState(() => _customProvider = p.$1),
                child: Container(
                  width: 88, padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: selected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(p.$4, size: 18, color: selected ? theme.colorScheme.primary : null),
                      const SizedBox(height: 3),
                      Text(p.$2, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(p.$3, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!isLocal) ...[
          const SizedBox(height: 16),
          Text('Style', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: styles.map((s) {
              final selected = _customStyle == s.$1;
              return GestureDetector(
                onTap: () => setState(() => _customStyle = s.$1),
                child: Chip(
                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.$3, size: 14, color: selected ? theme.colorScheme.primary : null),
                    const SizedBox(width: 4),
                    Text(s.$2, style: TextStyle(fontSize: 11,
                        color: selected ? theme.colorScheme.primary : null)),
                  ]),
                  backgroundColor: selected ? theme.colorScheme.primaryContainer : null,
                  side: selected ? BorderSide(color: theme.colorScheme.primary) : BorderSide.none,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Custom prompt toggle
          Row(
            children: [
              Text('Custom Prompt', style: theme.textTheme.titleSmall),
              const Spacer(),
              Switch.adaptive(value: _customAdvanced, onChanged: (v) => setState(() => _customAdvanced = v)),
            ],
          ),
          if (_customAdvanced) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _customPromptCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe camera, lighting, motion...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        _generateButton(theme,
            isLocal ? 'Create Local Video' : 'Generate AI Video',
            isLocal ? Icons.movie_creation : Icons.auto_awesome,
            theme.colorScheme.primary),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildChipRow<T>({
    required List<(T, String, IconData)> items,
    required T selected,
    required ValueChanged<T> onSelected,
    required ThemeData theme,
  }) {
    return Row(
      children: items.map((item) {
        final isSelected = selected == item.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onSelected(item.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                ),
                child: Column(
                  children: [
                    Icon(item.$3, size: 20, color: isSelected ? theme.colorScheme.primary : Colors.grey[600]),
                    const SizedBox(height: 4),
                    Text(item.$2, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: isSelected ? theme.colorScheme.primary : null),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _generateButton(ThemeData theme, String label, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: FilledButton.icon(
        onPressed: _onGenerate,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(backgroundColor: color),
      ),
    );
  }

  // ── Generate Dispatch ──────────────────────────────────────────────────────

  void _onGenerate() {
    Navigator.of(context).pop();
    switch (_selectedScenario) {
      case 'product':
        final name = _productNameCtrl.text.isNotEmpty ? _productNameCtrl.text : 'Product';
        final desc = _productDescCtrl.text.isNotEmpty ? _productDescCtrl.text : null;
        widget.onGenerate(
          provider: 'local',
          style: _productStyle,
          scenario: 'product',
          aspectRatio: _productPlatform,
          productName: name,
          customPrompt: desc,
          duration: 8,
          mode: 'production',
          inputText: desc != null ? '$name - $desc' : name,
        );
      case 'portrait':
        // Map UI effects to FFmpeg effects
        final ffmpegEffect = switch (_portraitEffect) {
          'cinematic_zoom' => 'zoom_in',
          'dramatic_light' => 'ken_burns',
          'pulse_glow'     => 'pulse',
          'slow_orbit'     => 'pan_left',
          _                => 'ken_burns',
        };
        widget.onGenerate(
          provider: 'local',
          style: 'cinematic',
          scenario: 'portrait',
          aspectRatio: _portraitPlatform,
          effect: ffmpegEffect,
          duration: _portraitDuration,
          mode: 'production',
          inputText: 'Close-up portrait with ${_portraitEffect.replaceAll('_', ' ')} effect',
        );
      case 'novel':
        if (_novelTextCtrl.text.trim().isEmpty) return;
        widget.onGenerate(
          provider: 'local',
          style: _novelStyle,
          scenario: 'novel',
          aspectRatio: '16:9',
          inputText: _novelTextCtrl.text.trim(),
          duration: _novelDuration,
          mode: 'production',
        );
      default: // custom
        widget.onGenerate(
          provider: _customProvider,
          style: _customStyle,
          customPrompt: _customAdvanced ? _customPromptCtrl.text : null,
          scenario: 'custom',
        );
    }
  }
}
