class WorkerPool {
  final List<Worker> _workers = [];

  void addWorker(Worker worker) {
    _workers.add(worker);
  }

  List<Worker> getAllWorkers() {
    return List.from(_workers);
  }
}

class Worker {
  final String id;
  final String name;

  Worker({required this.id, required this.name});
}
