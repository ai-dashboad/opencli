import 'dart:async';
import 'dart:collection';
import 'package:opencli_daemon/task_queue/task.dart';
import 'package:opencli_daemon/task_queue/worker_pool.dart';

/// Task management system - Queue, assign, execute tasks
class TaskManager {
  final WorkerPool workerPool;
  final Queue<Task> _pendingTasks = Queue<Task>();
  final Map<String, Task> _activeTasks = {};
  final Map<String, Task> _completedTasks = {};

  TaskManager({required this.workerPool});

  Future<Task> createTask({
    required String title,
    required String description,
    required Role requiredRole,
    required List<String> automationSteps,
  }) async {
    final task = Task(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      requiredRole: requiredRole,
      automationSteps: automationSteps,
      status: TaskStatus.pending,
      createdAt: DateTime.now(),
    );

    _pendingTasks.add(task);
    return task;
  }
}

enum TaskStatus { pending, assigned, inProgress, completed }
enum Role { developer, designer, qa }

class Task {
  final String id;
  final String title;
  final String description;
  final Role requiredRole;
  final List<String> automationSteps;
  TaskStatus status;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredRole,
    required this.automationSteps,
    required this.status,
    required this.createdAt,
  });
}
