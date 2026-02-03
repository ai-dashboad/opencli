import 'dart:io';
import 'package:flutter/foundation.dart';

void main() {
  print('=== macOS UI 平台检测 ===');
  print('Platform.isMacOS: ${Platform.isMacOS}');
  print('kIsWeb: $kIsWeb');
  print('应该使用 macOS UI: ${!kIsWeb && Platform.isMacOS}');

  if (!kIsWeb && Platform.isMacOS) {
    print('✅ 正确！应该看到 MacosApp + 侧边栏导航');
  } else {
    print('❌ 将使用 MaterialApp + 底部导航栏');
  }
}
