import 'dart:io' show Platform;
import 'package:flutter_skill/flutter_skill.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'services/daemon_service.dart';
import 'services/tray_service.dart';
import 'services/hotkey_service.dart';
import 'services/startup_service.dart';
import 'widgets/daemon_status_card.dart';
import 'pages/chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized();
  }

  // Initialize desktop features on desktop platforms
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await _initDesktopFeatures();
  }

  runApp(const OpenCLIApp());
}

/// Initialize desktop-specific features (window management, system tray)
Future<void> _initDesktopFeatures() async {
  // Window management setup
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(900, 650),
    minimumSize: Size(700, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // macOS style
    title: 'OpenCLI',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Note: System tray is initialized by TrayService in the main widget
}

class OpenCLIApp extends StatelessWidget {
  const OpenCLIApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use native macOS UI on macOS, Material elsewhere
    if (!kIsWeb && Platform.isMacOS) {
      return MacosApp(
        title: 'OpenCLI',
        theme: MacosThemeData.light(),
        darkTheme: MacosThemeData.dark(),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const MacOSHomePage(),
      );
    }

    // Fallback to Material Design for other platforms
    return MaterialApp(
      title: 'OpenCLI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const MaterialHomePage(),
    );
  }
}

// ============== macOS Native UI ==============

class MacOSHomePage extends StatefulWidget {
  const MacOSHomePage({super.key});

  @override
  State<MacOSHomePage> createState() => _MacOSHomePageState();
}

class _MacOSHomePageState extends State<MacOSHomePage> with WindowListener, TrayListener {
  int _selectedIndex = 0;
  final DaemonService _daemonService = DaemonService();

  // Desktop services
  final TrayService _trayService = TrayService();
  final HotkeyService _hotkeyService = HotkeyService();
  final StartupService _startupService = StartupService();

  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this); // Register tray listener on State
    _initDesktopServices();
    _connectToDaemon();
  }

  Future<void> _initDesktopServices() async {
    // Initialize tray service (without TrayListener, we handle it here)
    await _trayService.initWithoutListener();
    await _hotkeyService.init();
    await _startupService.init();
  }

  @override
  void onWindowClose() async {
    // 关闭窗口时不退出应用，只是隐藏窗口
    // 托盘图标会继续显示，用户可以通过托盘重新打开窗口
    await windowManager.hide();
  }

  Future<void> _connectToDaemon() async {
    setState(() => _isConnecting = true);
    try {
      await _daemonService.connect();
    } catch (e) {
      debugPrint('Failed to connect: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  // ========== TrayListener callbacks ==========
  @override
  void onTrayIconMouseDown() {
    debugPrint('🖱️  [State] Tray icon LEFT click detected');
    if (Platform.isWindows) {
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    debugPrint('🖱️  [State] Tray icon RIGHT click detected');
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('🔔 [State] TRAY MENU CLICK DETECTED!');
    debugPrint('   - Menu item key: ${menuItem.key}');
    debugPrint('   - Menu item label: ${menuItem.label}');

    _trayService.handleMenuClick(menuItem.key ?? '');
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this); // Remove tray listener
    _trayService.dispose();
    _hotkeyService.dispose();
    _daemonService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosWindow(
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
                leading: const MacosIcon(CupertinoIcons.chat_bubble_fill),
                label: const Text('Chat'),
              ),
              SidebarItem(
                leading: const MacosIcon(CupertinoIcons.chart_bar_fill),
                label: const Text('Status'),
              ),
              SidebarItem(
                leading: const MacosIcon(CupertinoIcons.gear_alt_fill),
                label: const Text('Settings'),
              ),
            ],
          );
        },
      ),
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildChatPage(),
          _buildStatusPage(),
          _buildSettingsPage(),
        ],
      ),
    );
  }

  Widget _buildChatPage() {
    return ContentArea(
      builder: (context, scrollController) {
        return Column(
          children: [
            // Toolbar
            ToolBar(
              title: const Text('Chat'),
              titleWidth: 200,
              actions: [
                ToolBarIconButton(
                  icon: MacosIcon(
                    _isConnecting
                        ? CupertinoIcons.circle_fill
                        : (_daemonService.isConnected
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.exclamationmark_circle_fill),
                  ),
                  onPressed: _connectToDaemon,
                  label: _daemonService.isConnected ? 'Connected' : 'Disconnected',
                  showLabel: false,
                ),
              ],
            ),
            // Chat content
            Expanded(
              child: ChatPage(daemonService: _daemonService),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusPage() {
    return ContentArea(
      builder: (context, scrollController) {
        return Column(
          children: [
            const ToolBar(
              title: Text('Status'),
              titleWidth: 200,
            ),
            Expanded(
              child: StatusPage(daemonService: _daemonService),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsPage() {
    return ContentArea(
      builder: (context, scrollController) {
        return Column(
          children: [
            const ToolBar(
              title: Text('Settings'),
              titleWidth: 200,
            ),
            const Expanded(
              child: SettingsPage(),
            ),
          ],
        );
      },
    );
  }
}

// ============== Material Design UI (for non-macOS platforms) ==============

class MaterialHomePage extends StatefulWidget {
  const MaterialHomePage({super.key});

  @override
  State<MaterialHomePage> createState() => _MaterialHomePageState();
}

class _MaterialHomePageState extends State<MaterialHomePage> with WindowListener, TrayListener {
  int _selectedIndex = 0;
  final DaemonService _daemonService = DaemonService();

  // Desktop-only services
  final TrayService? _trayService = (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
      ? TrayService()
      : null;
  final HotkeyService? _hotkeyService = (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
      ? HotkeyService()
      : null;
  final StartupService? _startupService = (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
      ? StartupService()
      : null;

  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      windowManager.addListener(this);
      trayManager.addListener(this);
    }
    _initDesktopServices();
    _connectToDaemon();
  }

  Future<void> _initDesktopServices() async {
    await _trayService?.initWithoutListener();
    await _hotkeyService?.init();
    await _startupService?.init();
  }

  @override
  void onWindowClose() async {
    // 关闭窗口时不退出应用，只是隐藏窗口
    await windowManager.hide();
  }

  Future<void> _connectToDaemon() async {
    setState(() => _isConnecting = true);
    try {
      await _daemonService.connect();
      // Listen for auth_success to update the connection icon
      _daemonService.messages.listen((msg) {
        if (!mounted) return;
        final type = msg['type'] as String?;
        if (type == 'auth_success' || type == 'auth_required') {
          setState(() {}); // Rebuild to update connection icon
        }
      });
      // Wait briefly for auth_success before showing status
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        if (_daemonService.isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to OpenCLI Daemon'),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() {}); // Ensure icon updates
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  // ========== TrayListener callbacks ==========
  @override
  void onTrayIconMouseDown() {
    debugPrint('🖱️  [State-Material] Tray icon LEFT click detected');
    if (Platform.isWindows) {
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    debugPrint('🖱️  [State-Material] Tray icon RIGHT click detected');
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('🔔 [State-Material] TRAY MENU CLICK DETECTED!');
    debugPrint('   - Menu item key: ${menuItem.key}');
    debugPrint('   - Menu item label: ${menuItem.label}');

    _trayService?.handleMenuClick(menuItem.key ?? '');
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    _trayService?.dispose();
    _hotkeyService?.dispose();
    _daemonService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ChatPage(daemonService: _daemonService),
      StatusPage(daemonService: _daemonService),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenCLI'),
        elevation: 2,
        actions: [
          if (_isConnecting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Icon(
              _daemonService.isConnected
                  ? Icons.cloud_done
                  : Icons.cloud_off,
              color: _daemonService.isConnected ? Colors.green : Colors.red,
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ============== Legacy Pages ==============

class TasksPage extends StatefulWidget {
  final DaemonService daemonService;

  const TasksPage({super.key, required this.daemonService});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _listenToUpdates();
  }

  void _listenToUpdates() {
    widget.daemonService.messages.listen((message) {
      if (message['type'] == 'task_update') {
        setState(() {
          _tasks.add({
            'type': 'update',
            'status': message['status'],
            'time': DateTime.now(),
          });
        });
      }
    });
  }

  Future<void> _submitTask(String taskType, Map<String, dynamic> data) async {
    try {
      await widget.daemonService.submitTask(taskType, data);
      setState(() {
        _tasks.add({
          'type': taskType,
          'data': data,
          'time': DateTime.now(),
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
      ),
      body: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return ListTile(
            leading: const Icon(Icons.task_alt),
            title: Text(task['type'] ?? 'Unknown'),
            subtitle: Text(task['status'] ?? ''),
            trailing: Text(
              task['time'].toString().substring(11, 19),
            ),
          );
        },
      ),
    );
  }
}

class StatusPage extends StatelessWidget {
  final DaemonService daemonService;

  const StatusPage({super.key, required this.daemonService});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const DaemonStatusCard(),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Platform', Platform.operatingSystem),
                _buildInfoRow('Version', Platform.operatingSystemVersion),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        const Card(
          child: ListTile(
            leading: Icon(Icons.palette),
            title: Text('Theme'),
            subtitle: Text('System default'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifications'),
            subtitle: Text('Enabled'),
          ),
        ),
      ],
    );
  }
}
