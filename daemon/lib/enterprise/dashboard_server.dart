import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Enterprise dashboard web server
/// Provides web interface for task management, monitoring, and team collaboration
class DashboardServer {
  final int port;
  final String host;
  late HttpServer _server;
  final Router _router = Router();
  final Map<String, WebSocketChannel> _wsConnections = {};
  final Map<String, User> _users = {};
  final Map<String, Team> _teams = {};
  final Map<String, WorkerNode> _workers = {};

  DashboardServer({
    this.port = 8080,
    this.host = 'localhost',
  }) {
    _setupRoutes();
    _initializeDemoData();
  }

  /// Setup HTTP routes
  void _setupRoutes() {
    // Static pages
    _router.get('/', _handleIndex);
    _router.get('/dashboard', _handleDashboard);
    _router.get('/tasks', _handleTasks);
    _router.get('/workers', _handleWorkers);
    _router.get('/analytics', _handleAnalytics);

    // API routes
    _router.get('/api/users', _handleGetUsers);
    _router.post('/api/users', _handleCreateUser);
    _router.get('/api/teams', _handleGetTeams);
    _router.post('/api/teams', _handleCreateTeam);
    _router.get('/api/workers', _handleGetWorkers);
    _router.post('/api/tasks', _handleCreateTask);
    _router.get('/api/tasks', _handleGetTasks);
    _router.get('/api/tasks/<taskId>', _handleGetTask);
    _router.put('/api/tasks/<taskId>/assign', _handleAssignTask);
    _router.put('/api/tasks/<taskId>/status', _handleUpdateTaskStatus);
    _router.get('/api/analytics/overview', _handleAnalyticsOverview);
    _router.get('/api/analytics/performance', _handlePerformanceMetrics);

    // WebSocket for real-time updates
    _router.get('/ws', webSocketHandler(_handleWebSocket));
  }

  /// Initialize demo data
  void _initializeDemoData() {
    // Create demo users
    _users['admin'] = User(
      id: 'admin',
      name: 'Admin User',
      email: 'admin@company.com',
      role: UserRole.admin,
    );
    _users['manager'] = User(
      id: 'manager',
      name: 'Team Manager',
      email: 'manager@company.com',
      role: UserRole.manager,
    );

    // Create demo teams
    _teams['engineering'] = Team(
      id: 'engineering',
      name: 'Engineering',
      members: ['admin', 'manager'],
    );

    // Create demo workers
    _workers['worker-1'] = WorkerNode(
      id: 'worker-1',
      name: 'Desktop Worker 1',
      type: WorkerType.human,
      status: WorkerStatus.idle,
      capabilities: ['coding', 'testing', 'documentation'],
    );
    _workers['ai-worker-1'] = WorkerNode(
      id: 'ai-worker-1',
      name: 'AI Assistant 1',
      type: WorkerType.ai,
      status: WorkerStatus.idle,
      capabilities: ['code_generation', 'analysis', 'research'],
    );
  }

  /// Start the dashboard server
  Future<void> start() async {
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(_router.call);

    _server = await shelf_io.serve(handler, host, port);
    print('Dashboard server running on http://$host:$port');
  }

  /// Stop the dashboard server
  Future<void> stop() async {
    await _server.close();
    for (var channel in _wsConnections.values) {
      await channel.sink.close();
    }
    _wsConnections.clear();
  }

  /// CORS middleware
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  final Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  /// Route handlers
  Response _handleIndex(Request request) {
    return Response.ok(_generateIndexHtml(), headers: {
      'Content-Type': 'text/html',
    });
  }

  Response _handleDashboard(Request request) {
    return Response.ok(_generateDashboardHtml(), headers: {
      'Content-Type': 'text/html',
    });
  }

  Response _handleTasks(Request request) {
    return Response.ok(_generateTasksHtml(), headers: {
      'Content-Type': 'text/html',
    });
  }

  Response _handleWorkers(Request request) {
    return Response.ok(_generateWorkersHtml(), headers: {
      'Content-Type': 'text/html',
    });
  }

  Response _handleAnalytics(Request request) {
    return Response.ok(_generateAnalyticsHtml(), headers: {
      'Content-Type': 'text/html',
    });
  }

  /// API handlers
  Response _handleGetUsers(Request request) {
    final users = _users.values.map((u) => u.toJson()).toList();
    return Response.ok(
      jsonEncode({'users': users}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleCreateUser(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final user = User(
      id: data['id'] as String,
      name: data['name'] as String,
      email: data['email'] as String,
      role: UserRole.values.byName(data['role'] as String),
    );

    _users[user.id] = user;

    return Response.ok(
      jsonEncode(user.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _handleGetTeams(Request request) {
    final teams = _teams.values.map((t) => t.toJson()).toList();
    return Response.ok(
      jsonEncode({'teams': teams}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleCreateTeam(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final team = Team(
      id: data['id'] as String,
      name: data['name'] as String,
      members: (data['members'] as List<dynamic>).cast<String>(),
    );

    _teams[team.id] = team;

    return Response.ok(
      jsonEncode(team.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _handleGetWorkers(Request request) {
    final workers = _workers.values.map((w) => w.toJson()).toList();
    return Response.ok(
      jsonEncode({'workers': workers}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleCreateTask(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final task = {
      'id': 'task-${DateTime.now().millisecondsSinceEpoch}',
      'title': data['title'],
      'description': data['description'],
      'type': data['type'],
      'priority': data['priority'],
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    // Broadcast to WebSocket clients
    _broadcastUpdate({
      'type': 'task_created',
      'task': task,
    });

    return Response.ok(
      jsonEncode(task),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _handleGetTasks(Request request) {
    // Demo tasks
    final tasks = [
      {
        'id': 'task-1',
        'title': 'Implement user authentication',
        'description': 'Add JWT-based authentication',
        'type': 'development',
        'priority': 'high',
        'status': 'in_progress',
        'assigned_to': 'worker-1',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'task-2',
        'title': 'Analyze codebase for security issues',
        'description': 'Run security audit and generate report',
        'type': 'analysis',
        'priority': 'medium',
        'status': 'pending',
        'assigned_to': 'ai-worker-1',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    return Response.ok(
      jsonEncode({'tasks': tasks}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _handleGetTask(Request request, String taskId) {
    final task = {
      'id': taskId,
      'title': 'Sample Task',
      'description': 'Task description',
      'status': 'pending',
    };

    return Response.ok(
      jsonEncode(task),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleAssignTask(Request request, String taskId) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final workerId = data['worker_id'] as String;

    _broadcastUpdate({
      'type': 'task_assigned',
      'task_id': taskId,
      'worker_id': workerId,
    });

    return Response.ok(
      jsonEncode({'success': true}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleUpdateTaskStatus(Request request, String taskId) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final status = data['status'] as String;

    _broadcastUpdate({
      'type': 'task_status_updated',
      'task_id': taskId,
      'status': status,
    });

    return Response.ok(
      jsonEncode({'success': true}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _handleAnalyticsOverview(Request request) {
    final overview = {
      'total_tasks': 150,
      'completed_tasks': 98,
      'active_workers': 5,
      'ai_workers': 2,
      'human_workers': 3,
      'avg_completion_time': 3600, // seconds
      'success_rate': 0.95,
    };

    return Response.ok(
      jsonEncode(overview),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _handlePerformanceMetrics(Request request) {
    final metrics = {
      'cpu_usage': 0.45,
      'memory_usage': 0.68,
      'tasks_per_hour': 12,
      'worker_efficiency': {
        'worker-1': 0.92,
        'ai-worker-1': 0.88,
      },
    };

    return Response.ok(
      jsonEncode(metrics),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// WebSocket handler
  void _handleWebSocket(WebSocketChannel channel) {
    final connectionId = 'conn-${DateTime.now().millisecondsSinceEpoch}';
    _wsConnections[connectionId] = channel;

    print('WebSocket connected: $connectionId');

    channel.stream.listen(
      (message) {
        // Handle incoming WebSocket messages
        print('WebSocket message: $message');
      },
      onDone: () {
        _wsConnections.remove(connectionId);
        print('WebSocket disconnected: $connectionId');
      },
      onError: (error) {
        print('WebSocket error: $error');
        _wsConnections.remove(connectionId);
      },
    );
  }

  /// Broadcast update to all WebSocket clients
  void _broadcastUpdate(Map<String, dynamic> update) {
    final message = jsonEncode(update);
    for (var channel in _wsConnections.values) {
      channel.sink.add(message);
    }
  }

  /// HTML generators (basic templates)
  String _generateIndexHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <title>OpenCLI Enterprise Dashboard</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
    h1 { color: #333; }
    .nav { margin: 20px 0; }
    .nav a { margin-right: 20px; text-decoration: none; color: #007bff; }
    .nav a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <div class="container">
    <h1>OpenCLI Enterprise Dashboard</h1>
    <div class="nav">
      <a href="/dashboard">Dashboard</a>
      <a href="/tasks">Tasks</a>
      <a href="/workers">Workers</a>
      <a href="/analytics">Analytics</a>
    </div>
    <p>Welcome to the OpenCLI Enterprise Dashboard. Use the navigation above to manage your AI-powered workforce.</p>
  </div>
</body>
</html>
    ''';
  }

  String _generateDashboardHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <title>Dashboard - OpenCLI</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; }
    .card { background: white; padding: 20px; margin: 10px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; }
    .stat { text-align: center; }
    .stat-value { font-size: 32px; font-weight: bold; color: #007bff; }
    .stat-label { color: #666; margin-top: 5px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Dashboard Overview</h1>
    <div class="stats">
      <div class="card stat">
        <div class="stat-value">150</div>
        <div class="stat-label">Total Tasks</div>
      </div>
      <div class="card stat">
        <div class="stat-value">98</div>
        <div class="stat-label">Completed</div>
      </div>
      <div class="card stat">
        <div class="stat-value">5</div>
        <div class="stat-label">Active Workers</div>
      </div>
      <div class="card stat">
        <div class="stat-value">95%</div>
        <div class="stat-label">Success Rate</div>
      </div>
    </div>
    <div class="card">
      <h2>Recent Activity</h2>
      <p>Real-time task updates will appear here...</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  String _generateTasksHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <title>Tasks - OpenCLI</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
    th { background: #f8f9fa; font-weight: bold; }
    .badge { padding: 4px 8px; border-radius: 4px; font-size: 12px; }
    .badge-high { background: #dc3545; color: white; }
    .badge-medium { background: #ffc107; color: black; }
    .badge-low { background: #28a745; color: white; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Task Management</h1>
    <button onclick="location.href='/api/tasks'">View All Tasks (API)</button>
    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Title</th>
          <th>Type</th>
          <th>Priority</th>
          <th>Status</th>
          <th>Assigned To</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>task-1</td>
          <td>Implement user authentication</td>
          <td>development</td>
          <td><span class="badge badge-high">High</span></td>
          <td>In Progress</td>
          <td>worker-1</td>
        </tr>
        <tr>
          <td>task-2</td>
          <td>Analyze codebase for security</td>
          <td>analysis</td>
          <td><span class="badge badge-medium">Medium</span></td>
          <td>Pending</td>
          <td>ai-worker-1</td>
        </tr>
      </tbody>
    </table>
  </div>
</body>
</html>
    ''';
  }

  String _generateWorkersHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <title>Workers - OpenCLI</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; }
    .worker-card { background: white; padding: 20px; margin: 10px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .worker-name { font-size: 20px; font-weight: bold; }
    .worker-type { color: #666; }
    .status-idle { color: #28a745; }
    .status-busy { color: #dc3545; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Worker Management</h1>
    <div class="worker-card">
      <div class="worker-name">Desktop Worker 1</div>
      <div class="worker-type">Type: Human Worker</div>
      <div class="status-idle">Status: Idle</div>
      <div>Capabilities: coding, testing, documentation</div>
    </div>
    <div class="worker-card">
      <div class="worker-name">AI Assistant 1</div>
      <div class="worker-type">Type: AI Worker</div>
      <div class="status-idle">Status: Idle</div>
      <div>Capabilities: code_generation, analysis, research</div>
    </div>
  </div>
</body>
</html>
    ''';
  }

  String _generateAnalyticsHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <title>Analytics - OpenCLI</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
    .chart-placeholder { background: #f8f9fa; padding: 40px; text-align: center; color: #666; margin: 20px 0; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Analytics & Insights</h1>
    <div class="chart-placeholder">Task Completion Trend Chart (Placeholder)</div>
    <div class="chart-placeholder">Worker Performance Metrics (Placeholder)</div>
    <div class="chart-placeholder">Resource Utilization (Placeholder)</div>
  </div>
</body>
</html>
    ''';
  }
}

/// User model
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
    };
  }
}

enum UserRole { admin, manager, worker, viewer }

/// Team model
class Team {
  final String id;
  final String name;
  final List<String> members;

  Team({
    required this.id,
    required this.name,
    required this.members,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'members': members,
    };
  }
}

/// Worker node model
class WorkerNode {
  final String id;
  final String name;
  final WorkerType type;
  final WorkerStatus status;
  final List<String> capabilities;

  WorkerNode({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.capabilities,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'status': status.name,
      'capabilities': capabilities,
    };
  }
}

enum WorkerType { human, ai }
enum WorkerStatus { idle, busy, offline }
