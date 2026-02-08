#!/usr/bin/env dart

import 'dart:io';

void main() {
  print('📚 Syncing documentation across distribution channels...\n');

  final tasks = [
    _syncReadmeToVSCode,
    _syncReadmeToNpm,
    _syncReadmeToWebUI,
    _updateVersionInDocs,
  ];

  var successCount = 0;
  var failCount = 0;

  for (final task in tasks) {
    try {
      task();
      successCount++;
    } catch (e) {
      print('❌ Task failed: $e');
      failCount++;
    }
  }

  print('\n📊 Summary:');
  print('   ✅ Completed: $successCount tasks');
  if (failCount > 0) {
    print('   ❌ Failed: $failCount tasks');
    exit(1);
  }

  print('\n✨ Documentation sync completed successfully!');
}

void _syncReadmeToVSCode() {
  final source = File('README.md');
  final dest = File('ide-plugins/vscode/README.md');

  if (!source.existsSync()) {
    print('⚠️  Skipping VSCode sync: README.md not found');
    return;
  }

  if (!dest.parent.existsSync()) {
    print('⚠️  Skipping VSCode sync: vscode directory not found');
    return;
  }

  final content = source.readAsStringSync();

  // Add VSCode-specific header
  final vscodeContent = '''
# OpenCLI - VSCode Extension

This extension provides integration between VSCode and the OpenCLI autonomous company operating system.

---

$content
''';

  dest.writeAsStringSync(vscodeContent);
  print('✅ Synced README to VSCode extension');
}

void _syncReadmeToNpm() {
  final source = File('README.md');
  final npmDir = Directory('npm');

  if (!npmDir.existsSync()) {
    print('⚠️  Skipping npm sync: npm directory not found');
    return;
  }

  final dest = File('npm/README.md');

  if (!source.existsSync()) {
    print('⚠️  Skipping npm sync: README.md not found');
    return;
  }

  final content = source.readAsStringSync();

  // Add npm-specific installation instructions at the top
  final npmContent = '''
# OpenCLI - npm Package

**Universal AI Development Platform**

## Quick Install

\`\`\`bash
npm install -g @opencli/cli
\`\`\`

This package automatically downloads the native binary for your platform (macOS, Linux, Windows).

---

$content
''';

  dest.writeAsStringSync(npmContent);
  print('✅ Synced README to npm package');
}

void _syncReadmeToWebUI() {
  final source = File('README.md');
  final dest = File('web-ui/README.md');

  if (!source.existsSync()) {
    print('⚠️  Skipping Web UI sync: README.md not found');
    return;
  }

  if (!dest.parent.existsSync()) {
    print('⚠️  Skipping Web UI sync: web-ui directory not found');
    return;
  }

  dest.writeAsStringSync(source.readAsStringSync());
  print('✅ Synced README to Web UI');
}

void _updateVersionInDocs() {
  // Extract version from pubspec.yaml
  final pubspec = File('daemon/pubspec.yaml');
  if (!pubspec.existsSync()) {
    print('⚠️  Skipping version update: pubspec.yaml not found');
    return;
  }

  final content = pubspec.readAsStringSync();
  final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(content);

  if (versionMatch == null) {
    print('⚠️  Could not extract version from pubspec.yaml');
    return;
  }

  final version = versionMatch.group(1)!;

  // Update docs/INSTALLATION.md if exists
  final installDoc = File('docs/INSTALLATION.md');
  if (installDoc.existsSync()) {
    var installContent = installDoc.readAsStringSync();

    // Update version in installation commands
    installContent = installContent.replaceAllMapped(
      RegExp(r'(opencli@)\d+\.\d+\.\d+'),
      (match) => 'opencli@$version',
    );

    installDoc.writeAsStringSync(installContent);
    print('✅ Updated version in INSTALLATION.md to $version');
  }

  print('ℹ️  Current version: $version');
}
