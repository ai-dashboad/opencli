import 'dart:io';
import '../domain.dart';

class FilesMediaDomain extends TaskDomain {
  @override
  String get id => 'files_media';
  @override
  String get name => 'Files & Media';
  @override
  String get description => 'Compress, convert, and organize files and images';
  @override
  String get icon => 'folder';
  @override
  int get colorHex => 0xFF795548;

  @override
  List<String> get taskTypes => ['files_compress', 'files_convert', 'files_organize'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
    DomainIntentPattern(
      pattern: RegExp(r'^(?:compress|zip)\s+(?:images?\s+in\s+|files?\s+in\s+)?(.+)$', caseSensitive: false),
      taskType: 'files_compress',
      extractData: (m) => {'path': _resolveDir(m.group(1)!.trim())},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^convert\s+(\w+)\s+to\s+(\w+)(?:\s+in\s+(.+))?$', caseSensitive: false),
      taskType: 'files_convert',
      extractData: (m) => {'from_format': m.group(1)!, 'to_format': m.group(2)!, 'path': m.group(3) != null ? _resolveDir(m.group(3)!) : '~/Desktop'},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(?:organize|sort\s+files?\s+in)\s+(.+)$', caseSensitive: false),
      taskType: 'files_organize',
      extractData: (m) => {'path': _resolveDir(m.group(1)!.trim())},
    ),
  ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
    DomainOllamaIntent(
      intentName: 'files_compress',
      description: 'Compress files in a directory into a zip archive',
      parameters: {'path': 'directory path'},
      examples: [
        OllamaExample(input: 'compress images in downloads', intentJson: '{"intent": "files_compress", "confidence": 0.95, "parameters": {"path": "~/Downloads"}}'),
      ],
    ),
    DomainOllamaIntent(
      intentName: 'files_convert',
      description: 'Convert image files between formats (PNG, JPG, etc.)',
      parameters: {'from_format': 'source format', 'to_format': 'target format', 'path': 'directory'},
      examples: [
        OllamaExample(input: 'convert PNG to JPG', intentJson: '{"intent": "files_convert", "confidence": 0.95, "parameters": {"from_format": "png", "to_format": "jpg", "path": "~/Desktop"}}'),
      ],
    ),
    DomainOllamaIntent(
      intentName: 'files_organize',
      description: 'Organize files in a directory by type',
      parameters: {'path': 'directory to organize'},
      examples: [
        OllamaExample(input: 'organize my downloads', intentJson: '{"intent": "files_organize", "confidence": 0.95, "parameters": {"path": "~/Downloads"}}'),
      ],
    ),
  ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
    'files_compress': const DomainDisplayConfig(cardType: 'files', titleTemplate: 'Compressed', icon: 'archive', colorHex: 0xFF795548),
    'files_convert': const DomainDisplayConfig(cardType: 'files', titleTemplate: 'Converted', icon: 'transform', colorHex: 0xFF795548),
    'files_organize': const DomainDisplayConfig(cardType: 'files', titleTemplate: 'Organized', icon: 'create_new_folder', colorHex: 0xFF795548),
  };

  @override
  Future<Map<String, dynamic>> executeTask(String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'files_compress':
        return _compress(data);
      case 'files_convert':
        return _convert(data);
      case 'files_organize':
        return _organize(data);
      default:
        return {'success': false, 'error': 'Unknown files task: $taskType'};
    }
  }

  Future<Map<String, dynamic>> _compress(Map<String, dynamic> data) async {
    final path = _expandHome(data['path'] as String? ?? '~/Desktop');
    final archiveName = 'archive_${DateTime.now().millisecondsSinceEpoch}.zip';
    final archivePath = '$path/$archiveName';

    try {
      final result = await Process.run('bash', ['-c', 'cd "$path" && zip -r "$archivePath" . -x ".*" -x "__MACOSX/*"'])
          .timeout(const Duration(seconds: 120));
      return {
        'success': result.exitCode == 0,
        'archive': archivePath,
        'stdout': (result.stdout as String).trim(),
        'message': result.exitCode == 0 ? 'Created archive: $archiveName' : (result.stderr as String).trim(),
        'domain': 'files_media', 'card_type': 'files',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'files_media'};
    }
  }

  Future<Map<String, dynamic>> _convert(Map<String, dynamic> data) async {
    final fromFmt = (data['from_format'] as String? ?? '').toLowerCase();
    final toFmt = (data['to_format'] as String? ?? '').toLowerCase();
    final path = _expandHome(data['path'] as String? ?? '~/Desktop');

    try {
      // Use sips for image conversion on macOS
      final result = await Process.run('bash', ['-c',
        'cd "$path" && count=0; for f in *.$fromFmt; do [ -f "\$f" ] && sips -s format $toFmt "\$f" --out "\${f%.$fromFmt}.$toFmt" && count=\$((count+1)); done; echo "Converted \$count files"'
      ]).timeout(const Duration(seconds: 120));

      final output = (result.stdout as String).trim();
      return {
        'success': result.exitCode == 0,
        'from': fromFmt,
        'to': toFmt,
        'path': path,
        'message': output,
        'domain': 'files_media', 'card_type': 'files',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'files_media'};
    }
  }

  Future<Map<String, dynamic>> _organize(Map<String, dynamic> data) async {
    final path = _expandHome(data['path'] as String? ?? '~/Downloads');

    // Organize by file type into subdirectories
    final script = '''
cd "$path"
mkdir -p Images Documents Videos Music Archives Others

moved=0
for f in *; do
  [ -f "\$f" ] || continue
  ext="\${f##*.}"
  ext=\$(echo "\$ext" | tr '[:upper:]' '[:lower:]')
  case "\$ext" in
    jpg|jpeg|png|gif|bmp|svg|webp|heic|tiff) mv "\$f" Images/ 2>/dev/null && moved=\$((moved+1)) ;;
    pdf|doc|docx|xls|xlsx|ppt|pptx|txt|csv|md) mv "\$f" Documents/ 2>/dev/null && moved=\$((moved+1)) ;;
    mp4|mov|avi|mkv|wmv|flv|webm) mv "\$f" Videos/ 2>/dev/null && moved=\$((moved+1)) ;;
    mp3|wav|flac|aac|ogg|m4a) mv "\$f" Music/ 2>/dev/null && moved=\$((moved+1)) ;;
    zip|tar|gz|rar|7z|dmg) mv "\$f" Archives/ 2>/dev/null && moved=\$((moved+1)) ;;
    *) mv "\$f" Others/ 2>/dev/null && moved=\$((moved+1)) ;;
  esac
done

# Remove empty directories
for d in Images Documents Videos Music Archives Others; do
  rmdir "\$d" 2>/dev/null
done

echo "Organized \$moved files in $path"
''';

    try {
      final result = await Process.run('bash', ['-c', script])
          .timeout(const Duration(seconds: 60));
      return {
        'success': result.exitCode == 0,
        'path': path,
        'message': (result.stdout as String).trim(),
        'domain': 'files_media', 'card_type': 'files',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'files_media'};
    }
  }

  static String _resolveDir(String input) {
    final lower = input.toLowerCase().trim();
    final dirMap = {
      'downloads': '~/Downloads',
      'desktop': '~/Desktop',
      'documents': '~/Documents',
      'pictures': '~/Pictures',
      'music': '~/Music',
      'movies': '~/Movies',
      'home': '~',
    };
    return dirMap[lower] ?? input;
  }

  static String _expandHome(String path) {
    if (path.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return '$home${path.substring(1)}';
    }
    return path;
  }
}
