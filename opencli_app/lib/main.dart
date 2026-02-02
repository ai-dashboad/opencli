import 'dart:io' show Platform;
import 'package:flutter_skill/flutter_skill.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'services/daemon_service.dart';
import 'services/tray_service.dart';
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
    size: Size(800, 600),
    minimumSize: Size(600, 400),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'OpenCLI',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // System tray setup
  await _initSystemTray();
}

/// Initialize system tray icon and menu
Future<void> _initSystemTray() async {
  // Set tray icon based on platform
  String iconPath;
  if (Platform.isMacOS) {
    iconPath = 'assets/tray_icon_macos.png';
  } else if (Platform.isWindows) {
    iconPath = 'assets/tray_icon_windows.ico';
  } else {
    iconPath = 'assets/tray_icon_linux.png';
  }

  // Note: Icon files need to be added to assets
  // For now, we'll use a placeholder approach
  try {
    await trayManager.setIcon(iconPath);
  } catch (e) {
    debugPrint('Failed to set tray icon: $e');
  }

  // Set tray menu
  Menu menu = Menu(
    items: [
      MenuItem(
        key: 'show',
        label: 'Show OpenCLI',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit',
        label: 'Exit',
      ),
    ],
  );

  await trayManager.setContextMenu(menu);

  // Set tooltip
  await trayManager.setToolTip('OpenCLI - AI Task Orchestration');
}

class OpenCLIApp extends StatelessWidget {
  const OpenCLIApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final DaemonService _daemonService = DaemonService();
  final TrayService? _trayService = (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
      ? TrayService()
      : null;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _trayService?.init();
    _connectToDaemon();
  }

  Future<void> _connectToDaemon() async {
    setState(() => _isConnecting = true);
    try {
      await _daemonService.connect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Connected to OpenCLI Daemon'),
            backgroundColor: Colors.green,
          ),
        );
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

  @override
  void dispose() {
    _trayService?.dispose();
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task submitted: $taskType')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 100,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'OpenCLI Tasks',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Submit tasks to control your Mac',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _tasks.length,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final task = _tasks[_tasks.length - 1 - index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          task['type'] == 'update'
                              ? Icons.update
                              : Icons.play_arrow,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(task['type'] ?? 'Unknown'),
                        subtitle: Text(
                          '${task['time']}'.substring(0, 19),
                        ),
                        trailing: task['type'] == 'update'
                            ? Chip(label: Text(task['status'] ?? ''))
                            : null,
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _submitTask('system_info', {}),
                icon: const Icon(Icons.info),
                label: const Text('System Info'),
              ),
              ElevatedButton.icon(
                onPressed: () => _submitTask('screenshot', {}),
                icon: const Icon(Icons.camera),
                label: const Text('Screenshot'),
              ),
              ElevatedButton.icon(
                onPressed: () => _submitTask(
                  'open_url',
                  {'url': 'https://opencli.ai'},
                ),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open URL'),
              ),
              ElevatedButton.icon(
                onPressed: () => _submitTask(
                  'web_search',
                  {'query': 'OpenCLI mobile'},
                ),
                icon: const Icon(Icons.search),
                label: const Text('Web Search'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatusPage extends StatelessWidget {
  final DaemonService daemonService;

  const StatusPage({super.key, required this.daemonService});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DaemonStatusCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      daemonService.isConnected
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: daemonService.isConnected
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Daemon Connection',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatusRow(
                  'Status',
                  daemonService.isConnected ? 'Connected' : 'Disconnected',
                ),
                const Divider(),
                _buildStatusRow('Host', 'localhost:9876'),
                const Divider(),
                _buildStatusRow('Protocol', 'WebSocket'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Task Types',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    Chip(label: Text('system_info')),
                    Chip(label: Text('screenshot')),
                    Chip(label: Text('open_url')),
                    Chip(label: Text('web_search')),
                    Chip(label: Text('open_app')),
                    Chip(label: Text('close_app')),
                    Chip(label: Text('open_file')),
                    Chip(label: Text('create_file')),
                    Chip(label: Text('read_file')),
                    Chip(label: Text('delete_file')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
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
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          subtitle: const Text('Version 0.1.2+6'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'OpenCLI Mobile',
              applicationVersion: '0.1.2+6',
              applicationIcon: const Icon(Icons.terminal, size: 48),
              applicationLegalese: '© 2026 OpenCLI',
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'AI-powered task orchestration on mobile\n'
                    'Control your Mac from your iPhone',
                  ),
                ),
              ],
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Daemon Server'),
          subtitle: const Text('localhost:9876'),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('GitHub'),
          subtitle: const Text('github.com/ai-dashboad/opencli'),
        ),
      ],
    );
  }
}
