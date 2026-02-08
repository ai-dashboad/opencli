# 自动化输入测试

这个目录包含了在 iOS 和 Android 模拟器中自动输入文本的集成测试。

## 快速开始

### 1. 使用便捷脚本（推荐）

```bash
# 在 Android 模拟器运行
./scripts/auto_input_twitter_text.sh android

# 在 iOS 模拟器运行
./scripts/auto_input_twitter_text.sh ios

# 在两个模拟器都运行
./scripts/auto_input_twitter_text.sh both
```

### 2. 手动运行测试

```bash
# Android
cd opencli_app
flutter test integration_test/auto_input_test.dart -d emulator-5554

# iOS (使用设备 ID)
flutter test integration_test/auto_input_test.dart -d DEVICE_ID
```

## 测试内容

测试会自动执行以下操作：

1. ✅ 启动应用
2. ✅ 等待界面加载完成
3. ✅ 点击输入框
4. ✅ 自动输入完整的 Twitter/X 推广系统文本（202 字符）
5. ✅ 点击发送按钮
6. ✅ 等待 10 秒观察消息发送和 AI 响应
7. ✅ 验证文本是否正确显示

## 自定义测试文本

要修改自动输入的文本，编辑 [auto_input_test.dart](./auto_input_test.dart) 文件中的 `longText` 变量：

```dart
const longText = '''您的自定义文本...''';
```

## 测试结果

测试成功后，您会看到：

- ✅ 文本输入完成！
- ✅ 发送按钮已点击！
- ✅ 测试完成！
- 00:XX +2: All tests passed!

## 测试文件

- [auto_input_test.dart](./auto_input_test.dart) - 主测试文件
- [../scripts/auto_input_twitter_text.sh](../scripts/auto_input_twitter_text.sh) - 便捷脚本

## 故障排除

### 问题：未找到输入框或按钮

确保应用已正确启动，且主界面显示了聊天输入框。

### 问题：点击位置警告

这些是正常的警告信息，不影响测试结果。测试框架会自动处理这些情况。

### 问题：测试超时

增加 `pumpAndSettle` 的等待时间，或检查应用是否正常运行。

## 技术细节

- 使用 Flutter 集成测试框架
- 自动连接到 daemon (ws://10.0.2.2:9876)
- 支持 Android 和 iOS 模拟器
- 完全自动化，无需手动操作

## 相关文档

- [Flutter 集成测试文档](https://docs.flutter.dev/testing/integration-tests)
- [项目测试报告](../../test-results/COMPLETE_FLUTTER_SKILL_TEST.md)
