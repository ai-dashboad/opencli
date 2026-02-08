# OpenCLI 跨平台系统托盘应用设计

## 📋 目标

创建一个跨平台的系统托盘应用，提供统一的用户体验：
- macOS: 菜单栏
- Windows: 系统托盘
- Linux: 系统托盘

## 🎨 UI 设计目标

### macOS 优化版本
- ✨ 使用 SwiftUI 重写，符合 macOS Big Sur/Ventura 设计语言
- 🎭 流畅的动画和过渡效果
- 📊 清晰的信息层次和视觉反馈
- 🔔 实时状态更新
- ⚡ 快速操作按钮

### 跨平台 Flutter 版本
- 🌐 统一的 UI/UX 跨所有平台
- 🎨 适配各平台原生风格
- ⚡ 轻量级，低资源占用
- 🔄 实时同步 Daemon 状态

## 🏗️ 技术架构

### 双轨制方案

```
┌─────────────────────────────────────────────────┐
│                  macOS 用户                      │
├─────────────────────────────────────────────────┤
│  选项 1: 原生 Menubar App (Swift/SwiftUI)       │
│  选项 2: Flutter 托盘应用                        │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│            Windows/Linux 用户                    │
├─────────────────────────────────────────────────┤
│  Flutter 托盘应用 (唯一选项)                     │
└─────────────────────────────────────────────────┘
```

### Flutter 托盘应用架构

```
┌──────────────────────────────────────────┐
│     OpenCLI Tray (Flutter)               │
│  ┌────────────────────────────────────┐  │
│  │  Tray Manager                      │  │
│  │  - Icon rendering                  │  │
│  │  - Menu management                 │  │
│  │  - Platform adaptation             │  │
│  └────────────┬───────────────────────┘  │
│               │                           │
│  ┌────────────▼───────────────────────┐  │
│  │  Status Monitor                    │  │
│  │  - Poll daemon status API          │  │
│  │  - Update UI in real-time          │  │
│  │  - Show notifications              │  │
│  └────────────┬───────────────────────┘  │
│               │                           │
│  ┌────────────▼───────────────────────┐  │
│  │  Action Handler                    │  │
│  │  - Open Dashboard                  │  │
│  │  - Open Web UI                     │  │
│  │  - Manage settings                 │  │
│  │  - Quit application                │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
         │
         │ HTTP/WebSocket
         ▼
┌──────────────────────────────────────────┐
│      Daemon (Backend Service)            │
│  - Status API: localhost:9875            │
│  - WebSocket: localhost:9876             │
└──────────────────────────────────────────┘
```

## 📱 功能清单

### 核心功能（所有平台）

1. **状态显示**
   - ✅ 实时运行状态（运行/停止/错误）
   - 📊 版本号
   - ⏱️ 运行时间
   - 💾 内存使用
   - 📱 连接的移动客户端数量

2. **快速操作**
   - 🎨 AI Models 配置
   - 🔔 通知开关
   - 📊 打开 Dashboard
   - 🌐 打开 Web UI
   - ♻️ 刷新状态
   - ❌ 退出应用

3. **高级功能**
   - 📈 性能监控图表
   - 🔧 快速设置
   - 📝 查看日志
   - 🔄 重启 Daemon

### macOS 特有功能（SwiftUI 版本）

- 🎨 macOS 原生菜单样式
- ✨ 毛玻璃效果（NSVisualEffectView）
- 🌈 动态颜色支持（Light/Dark mode）
- 🔔 原生通知中心集成
- ⌨️ 全局快捷键支持

### Windows 特有功能

- 🖼️ Windows 11 圆角菜单
- 🔔 Windows Toast 通知
- 📌 任务栏图标闪烁提示

### Linux 特有功能

- 🐧 符合 freedesktop.org 规范
- 🔔 libnotify 通知
- 🎨 适配 GNOME/KDE 主题

## 🎨 UI/UX 设计

### macOS Menubar UI 改进

**当前版本**：
```
🟢 OpenCLI is running
Version: 0.1.0
Uptime: 0h 0m
Memory: 240.2 MB
Mobile Clients: 0
─────────────────
🤖 AI Models
🔔 通知: 关闭
📊 Open Dashboard
🌐 Open Web UI
♻️  Refresh
❌ Quit
```

**优化版本**：
```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  🟢 OpenCLI               ┃
┃  Running - v0.2.0         ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  ⏱️  Uptime: 2h 34m       ┃
┃  💾 Memory: 240.2 MB      ┃
┃  📱 Clients: 0            ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  🤖 AI Models        ⌘M  ┃
┃  📊 Dashboard        ⌘D  ┃
┃  🌐 Web UI           ⌘W  ┃
┃  🔧 Settings         ⌘,  ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  🔔 Notifications    ⌘N  ┃
┃     ☑️  Enabled           ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  ♻️  Refresh         ⌘R  ┃
┃  ❌ Quit             ⌘Q  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

### Flutter 托盘 UI

```dart
TrayMenu(
  title: 'OpenCLI',
  icon: 'assets/tray_icon.png',
  tooltip: 'OpenCLI - Running',
  items: [
    // Header with status
    TrayMenuHeader(
      title: 'OpenCLI',
      subtitle: 'Running - v0.2.0',
      statusColor: Colors.green,
    ),
    TrayMenuDivider(),

    // Status info
    TrayMenuInfo(
      items: [
        ('⏱️ Uptime', '2h 34m'),
        ('💾 Memory', '240.2 MB'),
        ('📱 Clients', '0'),
      ],
    ),
    TrayMenuDivider(),

    // Actions
    TrayMenuItem(
      icon: '🤖',
      title: 'AI Models',
      shortcut: 'Cmd+M',
      onTap: () => openAIModels(),
    ),
    TrayMenuItem(
      icon: '📊',
      title: 'Dashboard',
      shortcut: 'Cmd+D',
      onTap: () => openDashboard(),
    ),
    TrayMenuItem(
      icon: '🌐',
      title: 'Web UI',
      shortcut: 'Cmd+W',
      onTap: () => openWebUI(),
    ),
    TrayMenuDivider(),

    // Settings
    TrayMenuItem(
      icon: '♻️',
      title: 'Refresh',
      shortcut: 'Cmd+R',
      onTap: () => refresh(),
    ),
    TrayMenuItem(
      icon: '❌',
      title: 'Quit',
      shortcut: 'Cmd+Q',
      onTap: () => quit(),
    ),
  ],
)
```

## 🔧 实现步骤

### Phase 1: Flutter 跨平台托盘基础 ✅
1. 创建新的 Flutter 托盘应用模块（或集成到 opencli_app）
2. 配置 `tray_manager` 包
3. 添加托盘图标资源（macOS/Windows/Linux）
4. 实现基本的托盘菜单

### Phase 2: 状态监控和更新
1. 实现 Daemon Status API 轮询
2. 实时更新托盘图标和菜单
3. 添加状态指示器（运行/停止/错误）
4. 实现通知功能

### Phase 3: 交互功能
1. 实现所有菜单操作
2. 打开 Dashboard/Web UI
3. 快捷键支持
4. 设置管理

### Phase 4: macOS 原生优化（可选）
1. 使用 SwiftUI 重写 menubar-app
2. 添加高级 UI 效果
3. 原生通知集成
4. 性能优化

## 📦 依赖包

```yaml
dependencies:
  # 系统托盘支持
  tray_manager: ^0.2.3

  # 通知
  flutter_local_notifications: ^17.0.0

  # HTTP 请求
  http: ^1.2.2

  # 平台检测
  platform: ^3.1.0

  # 窗口管理
  window_manager: ^0.4.2
```

## 🎯 成功指标

- ✅ 托盘应用可在 macOS/Windows/Linux 上运行
- ✅ 实时显示 Daemon 状态
- ✅ 所有快捷操作正常工作
- ✅ 内存占用 < 50MB
- ✅ CPU 使用率 < 1% (idle)
- ✅ 符合各平台 UI 规范

## 🚀 下一步

1. 决定是否集成到 opencli_app 或创建独立应用
2. 实现 Flutter 托盘基础功能
3. 测试跨平台兼容性
4. 优化 macOS 原生版本（可选）
5. 发布和文档

---

**创建时间**: 2026-02-03
**作者**: Claude Code
**状态**: 设计阶段
