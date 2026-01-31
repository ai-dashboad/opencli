#!/usr/bin/env dart

import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('❌ Usage: dart scripts/bump_version.dart <version>');
    print('   Example: dart scripts/bump_version.dart 1.0.0');
    exit(1);
  }

  final version = arguments[0];

  // Validate version format (SemVer)
  final versionRegex = RegExp(r'^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$');
  if (!versionRegex.hasMatch(version)) {
    print('❌ Invalid version format: $version');
    print('   Version must follow Semantic Versioning (e.g., 1.0.0, 1.0.0-beta.1, 1.0.0+build.123)');
    exit(1);
  }

  print('📦 Updating version to $version...\n');

  final files = {
    // Rust CLI
    'cli/Cargo.toml': (content) => _updateCargoToml(content, version),

    // Dart Daemon
    'daemon/pubspec.yaml': (content) => _updatePubspecYaml(content, version),

    // VSCode Extension
    'ide-plugins/vscode/package.json': (content) => _updatePackageJson(content, version),

    // Web UI
    'web-ui/package.json': (content) => _updatePackageJson(content, version),

    // Flutter Skill Plugin
    'plugins/flutter-skill/pubspec.yaml': (content) => _updatePubspecYaml(content, version),

    // README.md
    'README.md': (content) => _updateReadme(content, version),
  };

  var successCount = 0;
  var failCount = 0;

  for (final entry in files.entries) {
    final filePath = entry.key;
    final updateFn = entry.value;

    final file = File(filePath);

    if (!file.existsSync()) {
      print('⚠️  Skipping $filePath (file not found)');
      continue;
    }

    try {
      final content = file.readAsStringSync();
      final updatedContent = updateFn(content);

      if (updatedContent != content) {
        file.writeAsStringSync(updatedContent);
        print('✅ Updated $filePath');
        successCount++;
      } else {
        print('⏭️  No changes needed in $filePath');
      }
    } catch (e) {
      print('❌ Failed to update $filePath: $e');
      failCount++;
    }
  }

  print('\n📊 Summary:');
  print('   ✅ Updated: $successCount files');
  if (failCount > 0) {
    print('   ❌ Failed: $failCount files');
    exit(1);
  }

  print('\n✨ Version bump completed successfully!');
}

String _updateCargoToml(String content, String version) {
  // Update version = "x.x.x"
  return content.replaceFirst(
    RegExp(r'^version\s*=\s*"[^"]+"', multiLine: true),
    'version = "$version"',
  );
}

String _updatePubspecYaml(String content, String version) {
  // Update version: x.x.x
  return content.replaceFirst(
    RegExp(r'^version:\s*\S+', multiLine: true),
    'version: $version',
  );
}

String _updatePackageJson(String content, String version) {
  // Update "version": "x.x.x"
  return content.replaceFirst(
    RegExp(r'"version":\s*"[^"]+"'),
    '"version": "$version"',
  );
}

String _updateReadme(String content, String version) {
  // Update **Version**: x.x.x at the bottom of README
  final updated = content.replaceFirst(
    RegExp(r'\*\*Version\*\*:\s*\S+'),
    '**Version**: $version',
  );

  // Also update version badges if they exist
  return updated.replaceAllMapped(
    RegExp(r'(badge/version-)[^-]+(-blue)'),
    (match) => '${match.group(1)}$version${match.group(2)}',
  );
}
