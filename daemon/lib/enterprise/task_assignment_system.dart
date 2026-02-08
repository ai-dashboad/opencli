import 'dart:async';
import 'dart:collection';

/// Intelligent task assignment system
/// Matches tasks with appropriate workers based on capabilities, availability, and workload
class TaskAssignmentSystem {
  final Map<String, Worker> _workers = {};
  final Queue<PendingTask> _taskQueue = Queue();
  final Map<String, AssignedTask> _assignedTasks = {};
  final StreamController<TaskAssignment> _assignmentController =
      StreamController.broadcast();

  Stream<TaskAssignment> get assignments => _assignmentController.stream;

  /// Register a worker in the system
  void registerWorker(Worker worker) {
    _workers[worker.id] = worker;
    print('Worker registered: ${worker.id} (${worker.type})');

    // Try to assign pending tasks to this new worker
    _processTaskQueue();
  }

  /// Unregister a worker
  void unregisterWorker(String workerId) {
    final worker = _workers.remove(workerId);
    if (worker != null) {
      print('Worker unregistered: $workerId');

      // Reassign tasks from this worker
      _reassignWorkerTasks(workerId);
    }
  }

  /// Submit a task for assignment
  Future<String> submitTask(TaskRequest request) async {
    final task = PendingTask(
      id: _generateTaskId(),
      title: request.title,
      description: request.description,
      type: request.type,
      requiredCapabilities: request.requiredCapabilities,
      priority: request.priority,
      estimatedDuration: request.estimatedDuration,
      submittedAt: DateTime.now(),
    );

    _taskQueue.add(task);
    print('Task submitted: ${task.id} - ${task.title}');

    // Try to assign immediately
    await _processTaskQueue();

    return task.id;
  }

  /// Process the task queue and assign tasks to available workers
  Future<void> _processTaskQueue() async {
    final tasksToRemove = <PendingTask>[];

    for (final task in _taskQueue) {
      final worker = _findBestWorker(task);

      if (worker != null) {
        await _assignTask(task, worker);
        tasksToRemove.add(task);
      }
    }

    // Remove assigned tasks from queue
    for (final task in tasksToRemove) {
      _taskQueue.remove(task);
    }
  }

  /// Find the best worker for a task
  Worker? _findBestWorker(PendingTask task) {
    final availableWorkers = _workers.values
        .where((w) => w.status == WorkerStatus.available)
        .where((w) => _hasRequiredCapabilities(w, task))
        .toList();

    if (availableWorkers.isEmpty) {
      return null;
    }

    // Score workers based on multiple factors
    availableWorkers.sort((a, b) {
      final scoreA = _calculateWorkerScore(a, task);
      final scoreB = _calculateWorkerScore(b, task);
      return scoreB.compareTo(scoreA); // Higher score is better
    });

    return availableWorkers.first;
  }

  /// Check if worker has required capabilities
  bool _hasRequiredCapabilities(Worker worker, PendingTask task) {
    return task.requiredCapabilities.every(
      (cap) => worker.capabilities.contains(cap),
    );
  }

  /// Calculate worker suitability score for a task
  double _calculateWorkerScore(Worker worker, PendingTask task) {
    double score = 0.0;

    // Factor 1: Capability match (0-40 points)
    final matchingCaps = task.requiredCapabilities
        .where((cap) => worker.capabilities.contains(cap))
        .length;
    score += (matchingCaps / task.requiredCapabilities.length) * 40;

    // Factor 2: Workload (0-30 points)
    // Prefer workers with lighter workload
    final workloadFactor =
        1.0 - (worker.currentTaskCount / 5.0).clamp(0.0, 1.0);
    score += workloadFactor * 30;

    // Factor 3: Performance history (0-20 points)
    score += worker.performanceRating * 20;

    // Factor 4: Worker type preference (0-10 points)
    if (task.type == TaskType.creative && worker.type == WorkerType.ai) {
      score += 10;
    } else if (task.type == TaskType.manual &&
        worker.type == WorkerType.human) {
      score += 10;
    } else {
      score += 5;
    }

    return score;
  }

  /// Assign a task to a worker
  Future<void> _assignTask(PendingTask task, Worker worker) async {
    final assignedTask = AssignedTask(
      taskId: task.id,
      workerId: worker.id,
      title: task.title,
      description: task.description,
      type: task.type,
      assignedAt: DateTime.now(),
      status: TaskStatus.assigned,
    );

    _assignedTasks[task.id] = assignedTask;
    worker.status = WorkerStatus.busy;
    worker.currentTaskCount++;

    // Notify listeners
    _assignmentController.add(TaskAssignment(
      taskId: task.id,
      workerId: worker.id,
      workerName: worker.name,
      assignedAt: assignedTask.assignedAt,
    ));

    print('Task assigned: ${task.id} -> ${worker.id}');
  }

  /// Update task status
  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    final task = _assignedTasks[taskId];
    if (task == null) {
      throw Exception('Task not found: $taskId');
    }

    task.status = status;

    if (status == TaskStatus.completed || status == TaskStatus.failed) {
      // Free up the worker
      final worker = _workers[task.workerId];
      if (worker != null) {
        worker.currentTaskCount--;
        if (worker.currentTaskCount == 0) {
          worker.status = WorkerStatus.available;
        }

        // Update worker performance
        if (status == TaskStatus.completed) {
          worker.completedTasks++;
          worker.performanceRating = (worker.performanceRating * 0.9) + 0.1;
        } else {
          worker.failedTasks++;
          worker.performanceRating = (worker.performanceRating * 0.9);
        }

        worker.performanceRating = worker.performanceRating.clamp(0.0, 1.0);
      }

      task.completedAt = DateTime.now();

      // Try to assign more tasks
      await _processTaskQueue();
    }

    print('Task status updated: $taskId -> ${status.name}');
  }

  /// Reassign all tasks from a worker
  void _reassignWorkerTasks(String workerId) {
    final tasksToReassign = _assignedTasks.values
        .where((t) => t.workerId == workerId)
        .where((t) =>
            t.status != TaskStatus.completed && t.status != TaskStatus.failed)
        .toList();

    for (final task in tasksToReassign) {
      // Convert back to pending task
      final pendingTask = PendingTask(
        id: task.taskId,
        title: task.title,
        description: task.description,
        type: task.type,
        requiredCapabilities: [],
        priority: 5,
        estimatedDuration: null,
        submittedAt: DateTime.now(),
      );

      _taskQueue.add(pendingTask);
      _assignedTasks.remove(task.taskId);
    }

    _processTaskQueue();
  }

  /// Get worker statistics
  Map<String, dynamic> getWorkerStats(String workerId) {
    final worker = _workers[workerId];
    if (worker == null) {
      throw Exception('Worker not found: $workerId');
    }

    final assignedTasks =
        _assignedTasks.values.where((t) => t.workerId == workerId).length;

    return {
      'worker_id': workerId,
      'name': worker.name,
      'type': worker.type.name,
      'status': worker.status.name,
      'current_tasks': assignedTasks,
      'completed_tasks': worker.completedTasks,
      'failed_tasks': worker.failedTasks,
      'performance_rating': worker.performanceRating,
      'capabilities': worker.capabilities,
    };
  }

  /// Get overall system statistics
  Map<String, dynamic> getSystemStats() {
    final totalWorkers = _workers.length;
    final availableWorkers =
        _workers.values.where((w) => w.status == WorkerStatus.available).length;
    final busyWorkers =
        _workers.values.where((w) => w.status == WorkerStatus.busy).length;
    final pendingTasks = _taskQueue.length;
    final activeTasks = _assignedTasks.values
        .where((t) =>
            t.status == TaskStatus.assigned ||
            t.status == TaskStatus.inProgress)
        .length;
    final completedTasks = _assignedTasks.values
        .where((t) => t.status == TaskStatus.completed)
        .length;

    return {
      'total_workers': totalWorkers,
      'available_workers': availableWorkers,
      'busy_workers': busyWorkers,
      'pending_tasks': pendingTasks,
      'active_tasks': activeTasks,
      'completed_tasks': completedTasks,
      'queue_depth': _taskQueue.length,
    };
  }

  /// Generate unique task ID
  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await _assignmentController.close();
  }
}

/// Worker model
class Worker {
  final String id;
  final String name;
  final WorkerType type;
  final List<String> capabilities;

  WorkerStatus status;
  int currentTaskCount;
  int completedTasks;
  int failedTasks;
  double performanceRating; // 0.0 to 1.0

  Worker({
    required this.id,
    required this.name,
    required this.type,
    required this.capabilities,
    this.status = WorkerStatus.available,
    this.currentTaskCount = 0,
    this.completedTasks = 0,
    this.failedTasks = 0,
    this.performanceRating = 0.8,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'status': status.name,
      'capabilities': capabilities,
      'current_task_count': currentTaskCount,
      'completed_tasks': completedTasks,
      'failed_tasks': failedTasks,
      'performance_rating': performanceRating,
    };
  }
}

enum WorkerType { human, ai, hybrid }

enum WorkerStatus { available, busy, offline }

/// Task request
class TaskRequest {
  final String title;
  final String description;
  final TaskType type;
  final List<String> requiredCapabilities;
  final int priority; // 1-10, higher is more urgent
  final Duration? estimatedDuration;

  TaskRequest({
    required this.title,
    required this.description,
    required this.type,
    required this.requiredCapabilities,
    this.priority = 5,
    this.estimatedDuration,
  });
}

/// Pending task
class PendingTask {
  final String id;
  final String title;
  final String description;
  final TaskType type;
  final List<String> requiredCapabilities;
  final int priority;
  final Duration? estimatedDuration;
  final DateTime submittedAt;

  PendingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.requiredCapabilities,
    required this.priority,
    this.estimatedDuration,
    required this.submittedAt,
  });
}

/// Assigned task
class AssignedTask {
  final String taskId;
  final String workerId;
  final String title;
  final String description;
  final TaskType type;
  final DateTime assignedAt;

  TaskStatus status;
  DateTime? completedAt;

  AssignedTask({
    required this.taskId,
    required this.workerId,
    required this.title,
    required this.description,
    required this.type,
    required this.assignedAt,
    this.status = TaskStatus.assigned,
    this.completedAt,
  });
}

enum TaskType {
  development,
  testing,
  analysis,
  research,
  documentation,
  creative,
  manual,
  automation,
}

enum TaskStatus {
  assigned,
  inProgress,
  completed,
  failed,
  cancelled,
}

/// Task assignment event
class TaskAssignment {
  final String taskId;
  final String workerId;
  final String workerName;
  final DateTime assignedAt;

  TaskAssignment({
    required this.taskId,
    required this.workerId,
    required this.workerName,
    required this.assignedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'worker_id': workerId,
      'worker_name': workerName,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }
}
