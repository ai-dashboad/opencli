# macOS Native UI Guidelines for opencli_app

## 🎨 Design Principles

opencli_app 应该看起来像真正的 macOS 原生应用，而不是跨平台应用。

### 核心原则
1. **遵循 Human Interface Guidelines** - Apple 的设计规范
2. **使用 macOS 原生组件** - 利用 macos_ui 包
3. **Big Sur 风格** - 圆角、毛玻璃、现代感
4. **流畅动画** - 自然的过渡效果
5. **深色模式支持** - 完美适配系统主题

---

## 📋 当前状态 vs 目标状态

### 当前问题
- ❌ 使用 Material Design（Android 风格）
- ❌ 硬编码颜色
- ❌ 无毛玻璃效果
- ❌ 标准 Flutter 组件

### 目标效果
- ✅ macOS Big Sur 原生风格
- ✅ 系统颜色自适应
- ✅ 毛玻璃（Vibrancy）效果
- ✅ SF Symbols 图标
- ✅ 原生菜单栏集成

---

## 🛠️ 实现方案

### 1. 使用 macOS UI 组件

```dart
import 'package:macos_ui/macos_ui.dart';

class MacOSStyleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'OpenCLI',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.system,  // 跟随系统
      home: MacosWindow(
        sidebar: Sidebar(...),  // 侧边栏
        child: ContentArea(...),  // 主内容区
      ),
    );
  }
}
```

### 2. 毛玻璃效果

```dart
// 使用 MacOS 原生毛玻璃
MacosScaffold(
  backgroundColor: Colors.transparent,
  // 启用毛玻璃背景
  toolBar: ToolBar(
    title: Text('OpenCLI'),
    decoration: BoxDecoration(
      color: MacosColors.transparent,
    ),
  ),
)
```

### 3. 原生菜单栏

```dart
// 创建 macOS 风格的菜单
PlatformMenuBar(
  menus: [
    PlatformMenu(
      label: 'OpenCLI',
      menus: [
        PlatformMenuItem(
          label: 'About OpenCLI',
          onSelected: () => showAboutDialog(),
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Preferences...',
              shortcut: SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
            ),
          ],
        ),
        PlatformMenuItem(
          label: 'Quit OpenCLI',
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyQ,
            meta: true,
          ),
          onSelected: () => exit(0),
        ),
      ],
    ),
  ],
)
```

### 4. SF Symbols 图标

```dart
// 使用 SF Symbols（macOS 原生图标）
import 'package:macos_ui/macos_ui.dart';

Icon(CupertinoIcons.chat_bubble)  // 聊天
Icon(CupertinoIcons.chart_bar)     // 状态
Icon(CupertinoIcons.gear)          // 设置
Icon(CupertinoIcons.paperplane)    // 发送
Icon(CupertinoIcons.mic)           // 语音
```

### 5. 侧边栏导航（macOS 风格）

```dart
MacosWindow(
  sidebar: Sidebar(
    minWidth: 200,
    builder: (context, scrollController) {
      return SidebarItems(
        currentIndex: _selectedIndex,
        onChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        scrollController: scrollController,
        items: [
          SidebarItem(
            leading: Icon(CupertinoIcons.chat_bubble),
            label: Text('Chat'),
          ),
          SidebarItem(
            leading: Icon(CupertinoIcons.chart_bar),
            label: Text('Status'),
          ),
          SidebarItem(
            leading: Icon(CupertinoIcons.gear),
            label: Text('Settings'),
          ),
        ],
      );
    },
  ),
  child: IndexedStack(
    index: _selectedIndex,
    children: [
      ChatPage(),
      StatusPage(),
      SettingsPage(),
    ],
  ),
)
```

---

## 🎨 颜色系统

### 使用系统颜色
```dart
// 自适应颜色（深色/浅色模式）
MacosColors.labelColor            // 主文本
MacosColors.secondaryLabelColor   // 次要文本
MacosColors.tertiaryLabelColor    // 三级文本
MacosColors.controlBackgroundColor // 控件背景
MacosColors.windowBackgroundColor  // 窗口背景
```

### 强调色
```dart
// 使用系统强调色（用户可在系统设置中修改）
MacosTheme.of(context).primaryColor
```

---

## 📐 布局规范

### 窗口尺寸
```dart
// 最小窗口尺寸
const minimumSize = Size(600, 400);

// 默认窗口尺寸
const defaultSize = Size(800, 600);

// 标题栏高度
const titleBarHeight = 52.0;

// 侧边栏宽度
const sidebarWidth = 200.0;
```

### 间距规范
```dart
// macOS 标准间距
const padding = EdgeInsets.all(20.0);         // 大间距
const paddingMedium = EdgeInsets.all(12.0);   // 中间距
const paddingSmall = EdgeInsets.all(8.0);     // 小间距
```

---

## 🎭 动画效果

### 页面切换
```dart
// macOS 风格的页面切换动画
AnimatedSwitcher(
  duration: Duration(milliseconds: 250),
  transitionBuilder: (child, animation) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  },
  child: pages[_selectedIndex],
)
```

### 列表项悬停
```dart
// 悬停效果
MacosListTile(
  leading: Icon(icon),
  title: Text(title),
  onTap: onTap,
  // 自动处理悬停效果
)
```

---

## 🔘 控件样式

### 按钮
```dart
// 主要按钮
PushButton(
  buttonSize: ButtonSize.large,
  child: Text('Submit'),
  onPressed: () {},
)

// 次要按钮
PushButton(
  buttonSize: ButtonSize.large,
  secondary: true,
  child: Text('Cancel'),
  onPressed: () {},
)
```

### 文本输入框
```dart
// macOS 风格输入框
MacosTextField(
  placeholder: 'Type a message...',
  maxLines: null,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(6),
  ),
)
```

### 开关
```dart
// macOS 风格开关
MacosSwitch(
  value: _isEnabled,
  onChanged: (value) {
    setState(() => _isEnabled = value);
  },
)
```

---

## 📊 示例：完整的 macOS 风格界面

```dart
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

class MacOSStyleOpenCLI extends StatefulWidget {
  @override
  State<MacOSStyleOpenCLI> createState() => _MacOSStyleOpenCLIState();
}

class _MacOSStyleOpenCLIState extends State<MacOSStyleOpenCLI> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'OpenCLI',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: PlatformMenuBar(
        menus: _buildMenus(),
        child: MacosWindow(
          // 侧边栏
          sidebar: Sidebar(
            minWidth: 200,
            builder: (context, controller) {
              return SidebarItems(
                currentIndex: _selectedIndex,
                onChanged: (index) {
                  setState(() => _selectedIndex = index);
                },
                scrollController: controller,
                items: [
                  SidebarItem(
                    leading: Icon(CupertinoIcons.chat_bubble_fill),
                    label: Text('Chat'),
                  ),
                  SidebarItem(
                    leading: Icon(CupertinoIcons.chart_bar_fill),
                    label: Text('Status'),
                  ),
                  SidebarItem(
                    leading: Icon(CupertinoIcons.gear_alt_fill),
                    label: Text('Settings'),
                  ),
                ],
              );
            },
          ),

          // 主内容区
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildChatPage(),
              _buildStatusPage(),
              _buildSettingsPage(),
            ],
          ),
        ),
      ),
    );
  }

  // 构建菜单
  List<PlatformMenu> _buildMenus() {
    return [
      PlatformMenu(
        label: 'OpenCLI',
        menus: [
          PlatformMenuItem(
            label: 'About OpenCLI',
            onSelected: () => _showAboutDialog(),
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: 'Preferences...',
                shortcut: SingleActivator(
                  LogicalKeyboardKey.comma,
                  meta: true,
                ),
                onSelected: () => setState(() => _selectedIndex = 2),
              ),
            ],
          ),
          PlatformMenuItem(
            label: 'Quit OpenCLI',
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyQ,
              meta: true,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildChatPage() {
    return ContentArea(
      builder: (context, scrollController) {
        return Column(
          children: [
            // 工具栏
            ToolBar(
              title: Text('Chat'),
              actions: [
                ToolBarIconButton(
                  icon: Icon(CupertinoIcons.mic),
                  onPressed: () {},
                  label: 'Voice',
                  showLabel: false,
                ),
              ],
            ),

            // 聊天消息列表
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.all(20),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return _buildMessage(messages[index]);
                },
              ),
            ),

            // 输入框
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MacosColors.transparent,
                border: Border(
                  top: BorderSide(
                    color: MacosColors.separatorColor,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MacosTextField(
                      placeholder: 'Type a message...',
                      maxLines: null,
                    ),
                  ),
                  SizedBox(width: 12),
                  PushButton(
                    buttonSize: ButtonSize.large,
                    child: Icon(CupertinoIcons.paperplane_fill),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusPage() {
    return ContentArea(
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.all(20),
          children: [
            // 状态卡片
            MacosListTile(
              leading: Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: MacosColors.systemGreenColor,
              ),
              title: Text('Daemon Status'),
              subtitle: Text('Connected'),
            ),
            // 更多状态...
          ],
        );
      },
    );
  }

  Widget _buildSettingsPage() {
    return ContentArea(
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.all(20),
          children: [
            Text(
              'Desktop Features',
              style: MacosTheme.of(context).typography.headline,
            ),
            SizedBox(height: 20),
            MacosListTile(
              leading: Icon(CupertinoIcons.rocket_fill),
              title: Text('Launch at Startup'),
              trailing: MacosSwitch(
                value: true,
                onChanged: (value) {},
              ),
            ),
            // 更多设置...
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showMacosAlertDialog(
      context: context,
      builder: (context) {
        return MacosAlertDialog(
          appIcon: FlutterLogo(size: 64),
          title: Text('About OpenCLI'),
          message: Text(
            'Version 0.2.1+8\n\n'
            'AI-powered task orchestration\n'
            '© 2026 OpenCLI',
          ),
          primaryButton: PushButton(
            buttonSize: ButtonSize.large,
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }
}
```

---

## 📸 效果预览

### 浅色模式
- 干净的白色背景
- 柔和的阴影
- 清晰的文字
- 系统标准字体

### 深色模式
- 深灰色背景
- 毛玻璃效果
- 高对比度文字
- 护眼舒适

---

## ✅ 实施检查清单

- [ ] 替换 MaterialApp 为 MacosApp
- [ ] 使用 macOS 原生组件
- [ ] 实现侧边栏导航
- [ ] 添加菜单栏
- [ ] 使用系统颜色
- [ ] 添加毛玻璃效果
- [ ] 实现深色模式
- [ ] 使用 SF Symbols 图标
- [ ] 优化动画效果
- [ ] 测试所有状态

---

## 🎯 最终目标

**用户应该感觉不到这是一个 Flutter 应用，而是一个原生的 macOS 应用。**

完美集成到 macOS 生态系统中！
