import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opencli_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('自动输入测试', () {
    testWidgets('在聊天界面自动输入 Twitter/X 推广系统文本', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 要输入的文本
      const longText = '''我们需要一套自动化的 Twitter/X 技术推广系统：当 GitHub 仓库发布新版本（Release 或 Tag）时，系统能够自动生成并发布一条包含版本信息、更新要点和相关技术标签的推文；同时，系统应持续监控与项目相关的技术关键词（如编程语言、框架、开源话题等），自动筛选高相关度的推文，并以自然、不打扰的方式进行智能回复或互动，从而在不依赖人工运营的情况下，实现版本发布同步传播与持续的技术社区曝光''';

      // 等待界面加载完成
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 查找输入框 (使用 TextField)
      final textField = find.byType(TextField);
      expect(textField, findsAtLeastNWidgets(1));

      // 点击输入框
      await tester.tap(textField.first);
      await tester.pumpAndSettle();

      // 输入文本
      print('开始输入长文本...');
      await tester.enterText(textField.first, longText);
      await tester.pumpAndSettle();

      print('✅ 文本输入完成！');
      print('输入的文本长度: ${longText.length} 字符');

      // 查找发送按钮 (使用 IconButton)
      final sendButton = find.byType(IconButton);

      if (sendButton.evaluate().isNotEmpty) {
        print('找到发送按钮，准备点击...');

        // 点击发送按钮
        await tester.tap(sendButton.first);
        await tester.pumpAndSettle();

        print('✅ 发送按钮已点击！');
      } else {
        print('⚠️  未找到发送按钮');
      }

      // 等待消息发送和响应
      print('等待 10 秒以观察消息发送和 AI 响应...');
      await tester.pumpAndSettle(const Duration(seconds: 10));

      print('✅ 测试完成！');
    });

    testWidgets('验证文本是否正确显示', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      const testText = 'Twitter/X 技术推广系统';

      // 等待界面加载
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 查找并点击输入框
      final textField = find.byType(TextField);
      await tester.tap(textField.first);
      await tester.pumpAndSettle();

      // 输入文本
      await tester.enterText(textField.first, testText);
      await tester.pumpAndSettle();

      // 验证文本是否显示
      expect(find.text(testText), findsOneWidget);

      print('✅ 文本验证成功！');
    });
  });
}
