# Apple App Store 发布完整指南

## 📋 前提条件

- [x] Apple Developer 账号 ($99/年)
- [x] macOS 电脑 (用于 Xcode)
- [x] IPA 文件或 Xcode 项目
- [x] 应用图标和截图已准备
- [x] 应用描述已准备

---

## 🚀 第一步: Apple Developer 账号设置

### 1.1 注册 Apple Developer Program

1. 访问: https://developer.apple.com/programs/
2. 点击 **"Enroll"**
3. 使用 Apple ID 登录
4. 选择账号类型:
   - **Individual** (个人): $99/年
   - **Organization** (组织): $99/年 (需要 D-U-N-S Number)
5. 完成支付
6. 等待审核 (通常1-2天)

### 1.2 创建 App ID

1. 登录: https://developer.apple.com/account
2. 导航到: **Certificates, IDs & Profiles**
3. 选择 **Identifiers** → **App IDs**
4. 点击 **"+"** 创建新 App ID:
   ```
   Description: OpenCLI Mobile
   Bundle ID: com.opencli.mobile (Explicit)
   Capabilities:
   ☑ App Groups (如果需要)
   ☑ Push Notifications (如果需要)
   ```
5. 点击 **"Continue"** → **"Register"**

### 1.3 创建证书和配置文件

#### 创建发布证书

1. 在 Mac 上打开 **钥匙串访问**
2. 菜单: **钥匙串访问 > 证书助理 > 从证书颁发机构请求证书**
3. 填写信息:
   ```
   电子邮件: your-email@example.com
   常用名称: Your Name
   保存到磁盘
   ```
4. 上传到 Developer Portal:
   - **Certificates** → **Production** → **+**
   - 选择 **"App Store and Ad Hoc"**
   - 上传 CSR 文件
   - 下载证书并双击安装

#### 创建 Provisioning Profile

1. **Profiles** → **+**
2. 选择 **"App Store"**
3. 选择之前创建的 App ID
4. 选择证书
5. 命名: **OpenCLI Mobile App Store**
6. 下载并双击安装

---

## 📱 第二步: App Store Connect 设置

### 2.1 创建新应用

1. 登录: https://appstoreconnect.apple.com
2. 点击 **"我的 App"** → **"+"** → **"新建 App"**
3. 填写信息:
   ```
   平台: iOS
   名称: OpenCLI
   主要语言: 简体中文 或 English (U.S.)
   套装ID: com.opencli.mobile
   SKU: opencli-mobile-001
   完全访问权限: 是
   ```
4. 点击 **"创建"**

### 2.2 填写 App 信息

#### App 信息

```
名称: OpenCLI
副标题 (30字符): AI Task Orchestration
隐私政策URL: https://opencli.ai/privacy
```

#### 类别

```
主要类别: Developer Tools / 效率
次要类别: Utilities / 实用工具
```

### 2.3 定价和供应情况

```
价格: 免费
供应范围: 所有国家和地区
```

---

## 📝 第三步: 准备提交版本

### 3.1 创建新版本

1. 点击 **"+"** 或 **"准备提交"**
2. 填写版本信息:
   ```
   版本: 0.1.1
   版权: © 2026 OpenCLI Team
   ```

### 3.2 截图和预览

#### iPhone 截图 (必需)

**6.7英寸显示屏** (iPhone 14 Pro Max 等):
```
尺寸: 1290 x 2796 像素
格式: PNG, JPG (RGB, 不透明)
数量: 至少3张,最多10张

建议截图:
1. screenshot_67_tasks.png - 任务管理页面
2. screenshot_67_status.png - 状态监控页面
3. screenshot_67_settings.png - 设置页面
4. screenshot_67_dark.png - 深色模式
```

**6.5英寸显示屏** (iPhone XS Max, 11 Pro Max 等):
```
尺寸: 1242 x 2688 像素
数量: 至少3张
```

**5.5英寸显示屏** (iPhone 8 Plus 等):
```
尺寸: 1242 x 2208 像素
数量: 至少3张
```

#### iPad 截图 (可选)

**12.9英寸 iPad Pro**:
```
尺寸: 2048 x 2732 像素
数量: 至少3张
```

#### App 预览视频 (可选)

```
时长: 15-30秒
格式: M4V, MP4, MOV
分辨率: 与截图相同
```

### 3.3 描述信息

#### 推广文本 (170字符)

```
随时随地管理 AI 任务!OpenCLI Mobile 让您通过手机提交任务、监控状态、管理工作流。Material Design 3 设计,支持深色模式。
```

#### 描述

```
[从 APP_DESCRIPTION.md 复制中文或英文描述]
```

#### 关键词 (100字符,逗号分隔)

```
opencli,ai,task,automation,developer,workflow,productivity,mobile,命令,任务管理
```

#### 技术支持网址

```
https://github.com/ai-dashboad/opencli/issues
```

#### 营销网址 (可选)

```
https://opencli.ai
```

### 3.4 App 图标

```
尺寸: 1024 x 1024 像素
格式: PNG, 24-bit RGB, 不透明
不要圆角: Apple 会自动添加
文件: opencli_mobile/app_store_materials/icon_1024.png
```

---

## 📦 第四步: 上传构建版本

### 方法 1: 使用 Xcode (推荐)

#### 4.1 在 Xcode 中配置

1. 打开项目:
   ```bash
   cd /Users/cw/development/opencli/opencli_mobile/ios
   open Runner.xcworkspace
   ```

2. 选择 **Runner** 项目 → **Signing & Capabilities**

3. 配置签名:
   ```
   Team: 选择你的开发团队 (G9VG22HGJG)
   Bundle Identifier: com.opencli.mobile
   Automatically manage signing: ☑
   ```

4. 选择目标设备: **Generic iOS Device**

#### 4.2 Archive 构建

1. 菜单: **Product** → **Archive**
2. 等待构建完成 (可能需要几分钟)
3. Organizer 窗口会自动打开

#### 4.3 上传到 App Store

1. 在 Organizer 中选择刚创建的 archive
2. 点击 **"Distribute App"**
3. 选择 **"App Store Connect"**
4. 选择 **"Upload"**
5. 配置选项:
   ```
   ☑ Upload your app's symbols
   ☑ Manage Version and Build Number (自动)
   ☐ Include bitcode
   ```
6. 选择签名方式: **Automatically manage signing**
7. 点击 **"Upload"**
8. 等待上传完成

### 方法 2: 使用 Transporter App

#### 4.2.1 构建 IPA

```bash
cd /Users/cw/development/opencli/opencli_mobile
flutter build ios --release

# 使用 Xcode 导出 IPA
# 或使用命令行工具
```

#### 4.2.2 使用 Transporter 上传

1. 从 Mac App Store 下载 **Transporter**
2. 打开 Transporter 并登录
3. 点击 **"+"** 或拖入 IPA 文件
4. 点击 **"Deliver"**
5. 等待验证和上传

### 方法 3: 使用 altool (命令行)

```bash
xcrun altool --upload-app \
  --type ios \
  --file "path/to/opencli-mobile.ipa" \
  --username "your-apple-id@example.com" \
  --password "app-specific-password"
```

---

## ✅ 第五步: 完成提交信息

### 5.1 等待构建处理

上传后,在 App Store Connect:
1. 等待 **"正在处理"** 变为可选择
2. 通常需要 5-30 分钟

### 5.2 选择构建版本

1. 在版本页面,**"构建版本"** 部分
2. 点击 **"+"** 选择刚上传的构建
3. 选择版本号 **0.1.1 (5)**

### 5.3 版本发布信息

#### 此版本的新功能

```
OpenCLI Mobile 首次发布

✨ 主要功能:
• 任务管理 - 随时随地提交和监控 AI 任务
• 实时状态 - 追踪守护进程状态和系统健康
• 现代界面 - Material Design 3,支持深色模式
• 安全连接 - 加密通信保护您的数据
• 跨平台 - 与桌面和网页版无缝同步

📝 使用提示:
1. 配置您的 OpenCLI 服务器地址
2. 开始提交和监控任务
3. 享受移动端的便捷体验

需要 OpenCLI 服务器。访问 opencli.ai 了解详情。
```

### 5.4 App Review 信息

#### 联系信息

```
名字: Your Name
姓氏: Your Lastname
电话: +86 138-xxxx-xxxx
电子邮件: support@opencli.ai
```

#### 演示账号 (如需要)

```
用户名: reviewer@opencli.ai
密码: ReviewDemo2026!

说明:
此应用需要连接 OpenCLI 服务器才能完全使用。
为便于审核,我们提供了演示服务器:
- 服务器地址: demo.opencli.ai
- 无需登录即可查看界面和基本功能
```

#### 备注

```
审核说明:

OpenCLI Mobile 是 OpenCLI 平台的移动客户端。

测试方法:
1. 打开应用
2. 浏览 Tasks、Status、Settings 三个页面
3. 点击 "Submit New Task" 按钮会显示 "即将推出" 消息
4. 所有 UI 功能都可正常查看

完整功能需要:
- 用户自行部署的 OpenCLI 服务器
- 服务器地址配置
- 网络连接

应用本身不收集任何用户数据,所有数据都在用户的服务器和设备之间传输。

感谢审核!
```

### 5.5 内容权限

#### 年龄分级

回答问卷:
```
- 模拟赌博: 否
- 频繁/强烈的卡通或幻想暴力: 否
- 不频繁/轻微的成人/性暗示主题: 否
- 频繁/强烈的恐怖/惊悚主题: 否
- 不频繁/轻微的粗俗或低俗幽默: 否
... (所有问题都选 "否")

结果: 4+
```

#### 版权

```
版权: © 2026 OpenCLI Team
```

### 5.6 导出合规性

```
App 是否使用加密: 是
加密类型: 标准加密 (HTTPS/TLS)
是否符合豁免条件: 是
CCATS: 不需要
```

---

## 🚀 第六步: 提交审核

### 6.1 最终检查

检查清单:
- [ ] 所有截图已上传 (至少3个尺寸)
- [ ] App 图标已上传 (1024x1024)
- [ ] 描述信息完整
- [ ] 关键词已填写
- [ ] 构建版本已选择
- [ ] 版本发布信息已填写
- [ ] App Review 信息已填写
- [ ] 年龄分级已完成
- [ ] 导出合规性已确认
- [ ] 隐私政策 URL 可访问

### 6.2 提交审核

1. 检查所有黄色警告标记
2. 点击右上角 **"提交以供审核"**
3. 确认提交
4. 等待审核

**审核时间**: 通常24-48小时

---

## 📊 第七步: 审核后续

### 审核状态

- **等待审核**: 已提交,排队中
- **正在审核**: Apple 正在审核
- **被拒绝**: 需要修改后重新提交
- **准备销售**: 审核通过,可发布
- **可供销售**: 已在 App Store 上线

### 如果被拒绝

1. 查看拒绝原因
2. 在 **"Resolution Center"** 回复
3. 修改应用或提供说明
4. 重新提交审核

### 发布应用

审核通过后:
- 自动发布: 审核通过后立即上线
- 手动发布: 点击 **"发布此版本"**

---

## 🔄 第八步: 更新应用

### 创建新版本

1. 更新代码
2. 修改版本号:
   ```dart
   // pubspec.yaml
   version: 0.1.2+6  // version+build
   ```
3. 构建新版本:
   ```bash
   flutter build ios --release
   ```
4. Archive 并上传
5. 在 App Store Connect 创建新版本
6. 填写 "此版本的新功能"
7. 提交审核

---

## 🎯 快速命令参考

### 构建 iOS Release

```bash
cd /Users/cw/development/opencli/opencli_mobile

# 清理之前的构建
flutter clean
flutter pub get

# 构建 iOS
flutter build ios --release --no-codesign

# 输出位置:
# ios/build/ios/iphoneos/Runner.app
```

### 使用 Xcode Archive

```bash
# 打开 Xcode
cd opencli_mobile/ios
open Runner.xcworkspace

# 然后在 Xcode 中:
# Product → Archive
```

---

## 🆘 常见问题

### Q: 如何生成 App-Specific Password?

**A:**
1. 访问: https://appleid.apple.com
2. 登录
3. 安全 → App-Specific Passwords
4. 生成新密码
5. 用于 altool 或 Transporter

### Q: Xcode 签名错误?

**A:**
1. 检查 Team 是否选择正确
2. 确认 Bundle ID 与 App Store Connect 一致
3. 确认证书和配置文件有效
4. 尝试 "Automatically manage signing"

### Q: 审核需要多久?

**A:** 通常 24-48 小时,高峰期可能需要 3-5 天

### Q: 如何加快审核?

**A:**
- 提供清晰的审核说明
- 提供测试账号
- 确保应用稳定性
- 遵守所有指南

---

## 📞 支持资源

- **App Store Connect 帮助**: https://help.apple.com/app-store-connect
- **审核指南**: https://developer.apple.com/app-store/review/guidelines/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/

---

**准备时间**: 2026-01-31
**预计审核**: 24-48 小时
**状态**: 📋 材料准备完成,需 Xcode 上传构建
