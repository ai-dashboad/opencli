# 应用商店提交完整检查清单

**应用**: OpenCLI Mobile
**版本**: 0.1.1 (Build 5)
**日期**: 2026-01-31

---

## 📋 通用准备工作

### 构建文件
- [ ] Android AAB 已构建: `opencli_mobile/build/app/outputs/bundle/release/app-release.aab` (38MB)
- [ ] Android APK 已构建: `opencli_mobile/build/app/outputs/flutter-apk/app-release.apk` (43MB)
- [ ] iOS 构建已准备 (通过 Xcode Archive)

### 应用素材
- [ ] 应用图标 1024x1024 (iOS)
- [ ] 应用图标 512x512 (Android)
- [ ] 手机截图 (至少3张)
  - [ ] 任务管理页面
  - [ ] 状态监控页面
  - [ ] 设置页面
  - [ ] 深色模式
- [ ] Feature Graphic 1024x500 (Android)
- [ ] 应用描述 (中英文)
- [ ] 版本更新说明
- [ ] 隐私政策 URL: https://opencli.ai/privacy

---

## 🤖 Google Play Console 提交

### 账号准备
- [ ] Google Play Developer 账号已注册 ($25)
- [ ] 开发者协议已同意
- [ ] 支付方式已设置

### 应用创建
- [ ] 创建新应用
  - [ ] 应用名称: OpenCLI
  - [ ] 默认语言: 中文(简体) / English
  - [ ] 应用类型: 应用
  - [ ] 免费/付费: 免费

### Store Listing (商店详情)
- [ ] 应用名称: OpenCLI
- [ ] 简短说明 (80字符)
- [ ] 完整说明
- [ ] 应用图标 (512x512)
- [ ] Feature Graphic (1024x500)
- [ ] 手机截图 (2-8张, 1080x1920)
- [ ] 平板截图 (可选)
- [ ] 应用类别: 工具 / Developer Tools
- [ ] 标签和关键词
- [ ] 联系邮箱: support@opencli.ai
- [ ] 网站: https://opencli.ai
- [ ] 隐私政策: https://opencli.ai/privacy

### App Content (应用内容)
- [ ] 隐私政策已填写
  - [ ] 数据收集: 否
  - [ ] 数据共享: 否
- [ ] 广告: 否
- [ ] 目标年龄组: 18+
- [ ] 内容分级问卷完成
  - [ ] 结果: PEGI 3 / Everyone
- [ ] 数据安全表单完成

### 版本发布
- [ ] 上传 AAB 文件
- [ ] 选择应用签名: Google Play 应用签名
- [ ] 版本名称: 0.1.1
- [ ] 版本号: 5
- [ ] 版本更新说明已填写
- [ ] 国家/地区: 全球

### 发布轨道
- [ ] 内部测试 (建议先发布)
  - [ ] 测试员列表已创建
  - [ ] 测试链接已获取
- [ ] 或直接生产发布

### 提交
- [ ] 所有必填项已完成
- [ ] 预览商店详情页面
- [ ] 点击 "提交审核"
- [ ] 等待审核 (1-3天)

---

## 🍎 Apple App Store 提交

### 账号准备
- [ ] Apple Developer Program 已注册 ($99/年)
- [ ] 开发者协议已同意
- [ ] 税务和银行信息已填写

### Developer Portal 配置
- [ ] App ID 已创建: com.opencli.mobile
- [ ] 发布证书已创建并安装
- [ ] Provisioning Profile 已创建并安装
- [ ] Team ID: G9VG22HGJG

### App Store Connect 应用创建
- [ ] 创建新应用
  - [ ] 平台: iOS
  - [ ] 名称: OpenCLI
  - [ ] 语言: 简体中文 / English
  - [ ] Bundle ID: com.opencli.mobile
  - [ ] SKU: opencli-mobile-001

### App 信息
- [ ] 名称: OpenCLI
- [ ] 副标题 (30字符)
- [ ] 主要类别: Developer Tools
- [ ] 次要类别: Utilities
- [ ] 隐私政策 URL: https://opencli.ai/privacy
- [ ] 定价: 免费
- [ ] 供应国家: 全部

### 版本信息
- [ ] 版本号: 0.1.1
- [ ] 版权: © 2026 OpenCLI Team
- [ ] App 图标 (1024x1024)
- [ ] iPhone 6.7" 截图 (1290x2796, 3-10张)
- [ ] iPhone 6.5" 截图 (1242x2688, 3-10张)
- [ ] iPhone 5.5" 截图 (1242x2208, 3-10张)
- [ ] iPad 截图 (可选)

### 描述信息
- [ ] 推广文本 (170字符)
- [ ] 描述
- [ ] 关键词 (100字符)
- [ ] 技术支持 URL
- [ ] 营销 URL (可选)
- [ ] 此版本的新功能

### 构建上传
- [ ] Xcode 配置完成
  - [ ] Team 已选择
  - [ ] Bundle ID 正确
  - [ ] 签名配置正确
- [ ] Archive 构建完成
- [ ] 上传到 App Store Connect
  - [ ] 通过 Xcode Organizer
  - [ ] 或通过 Transporter
- [ ] 等待构建处理完成
- [ ] 选择构建版本

### App Review 信息
- [ ] 联系信息
  - [ ] 名字姓氏
  - [ ] 电话
  - [ ] 邮箱: support@opencli.ai
- [ ] 演示账号 (如需要)
  - [ ] 用户名: reviewer@opencli.ai
  - [ ] 密码和说明
- [ ] 审核备注
- [ ] 年龄分级问卷
  - [ ] 结果: 4+
- [ ] 导出合规性
  - [ ] 使用加密: 是 (HTTPS/TLS)
  - [ ] 符合豁免: 是

### 提交
- [ ] 所有必填项已完成
- [ ] 检查所有警告
- [ ] 点击 "提交以供审核"
- [ ] 等待审核 (24-48小时)

---

## 📸 截图制作指南

### Android 截图

```bash
# 使用 Flutter 生成截图
cd opencli_mobile

# 在模拟器或真机上运行
flutter run --release

# 截图快捷键:
# - macOS: Cmd + Shift + 4
# - Windows: Win + Shift + S
# - Android Emulator: Camera icon

# 或使用命令行截图工具
flutter screenshot

# 推荐尺寸: 1080 x 1920
```

### iOS 截图

```bash
# 使用 Xcode Simulator
# 1. 打开不同尺寸的模拟器:
#    - iPhone 14 Pro Max (6.7")
#    - iPhone 11 Pro Max (6.5")
#    - iPhone 8 Plus (5.5")

# 2. 运行应用
flutter run --release

# 3. 截图快捷键:
#    Cmd + S (在 Simulator 窗口)

# 截图会保存到桌面
```

### 截图美化工具

- **Figma**: 添加设备边框和背景
- **Sketch**: 专业设计工具
- **Screenshot Maker**: 在线工具
- **App Screenshot**: 专门的 App Store 截图工具

---

## 🎨 图标和图形准备

### 应用图标

```bash
# 准备 1024x1024 原图
# 然后生成所需尺寸:

# iOS - 使用 Xcode Asset Catalog
# Android - 使用 Android Studio Asset Studio

# 或使用在线工具:
# - https://appicon.co
# - https://makeappicon.com
```

### Feature Graphic (Android)

```
尺寸: 1024 x 500
内容建议:
- 应用名称: OpenCLI
- Slogan: AI Task Orchestration
- 简单的图标或界面预览
- 干净的背景
```

---

## 📝 文本内容准备

### 应用描述模板

已准备在: `opencli_mobile/app_store_materials/APP_DESCRIPTION.md`

包含:
- 中英文完整描述
- 关键词
- 版本更新说明
- 隐私政策说明
- 支持信息

### 审核说明模板

```
OpenCLI Mobile 是 OpenCLI 平台的移动客户端应用。

【测试方法】
1. 打开应用查看欢迎界面
2. 浏览 Tasks、Status、Settings 三个主要页面
3. UI 和导航功能完全可测试
4. 点击 "Submit New Task" 会显示 "即将推出" 提示

【完整功能说明】
应用需要连接用户自己部署的 OpenCLI 服务器:
- 用户配置服务器地址
- 通过 HTTPS 加密通信
- 所有数据仅在用户设备和服务器间传输
- 应用本身不收集或存储任何数据

【隐私和安全】
- 应用仅作为客户端工具
- 不收集用户个人信息
- 不包含广告或追踪
- 开源项目,代码可审查

感谢审核!
```

---

## ✅ 提交后跟进

### Google Play

- [ ] 监控审核状态
- [ ] 检查 Play Console 通知
- [ ] 如被拒绝,查看原因并修改
- [ ] 审核通过后检查商店页面
- [ ] 测试安装和更新流程

### App Store

- [ ] 监控审核状态 (App Store Connect)
- [ ] 检查邮件通知
- [ ] 如被拒绝,在 Resolution Center 回复
- [ ] 审核通过后选择发布时间
- [ ] 检查 App Store 页面显示

---

## 🎯 成功标准

### Google Play
- ✅ 应用已发布到生产轨道
- ✅ 商店页面正确显示
- ✅ 用户可以搜索和下载
- ✅ 评分和评论功能正常

### App Store
- ✅ 应用状态 "可供销售"
- ✅ 在 App Store 可搜索到
- ✅ 商店页面完整显示
- ✅ 可以正常下载安装

---

## 📊 发布时间线

| 阶段 | Google Play | App Store | 备注 |
|------|-------------|-----------|------|
| 账号注册 | 即时 | 1-2天 | Apple 需审核 |
| 材料准备 | 2-4小时 | 2-4小时 | 截图和描述 |
| 应用配置 | 1-2小时 | 2-3小时 | 填写表单 |
| 构建上传 | 10-30分钟 | 30-60分钟 | 含处理时间 |
| 审核等待 | 1-3天 | 1-2天 | 工作日 |
| **总计** | **2-5天** | **3-6天** | 从注册到发布 |

---

## 📞 紧急联系

### Google Play Support
- **帮助中心**: https://support.google.com/googleplay/android-developer
- **开发者支持**: developer-support@google.com

### Apple Developer Support
- **帮助中心**: https://developer.apple.com/support
- **App Store Connect 帮助**: https://help.apple.com/app-store-connect

---

## 🎓 额外资源

### 学习资料
- [ ] [Google Play 发布清单](https://developer.android.com/distribute/best-practices/launch/launch-checklist)
- [ ] [App Store 审核指南](https://developer.apple.com/app-store/review/guidelines/)
- [ ] [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### 工具
- [ ] Android Studio (截图和图标)
- [ ] Xcode (iOS 构建和上传)
- [ ] Transporter (iOS 上传备选)
- [ ] Figma/Sketch (截图美化)

---

**创建日期**: 2026-01-31
**最后更新**: 2026-01-31
**状态**: ✅ 所有材料已准备完成

**下一步**:
1. 注册开发者账号 (如未注册)
2. 制作应用截图
3. 按照指南逐步提交

🚀 **准备就绪,可以开始提交!**
