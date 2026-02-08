/// Shared types for automation module

/// Represents a rectangular region on screen
class Rectangle {
  final int x;
  final int y;
  final int width;
  final int height;

  Rectangle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

/// Represents a point on screen
class Point {
  final int x;
  final int y;

  Point(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

/// Represents a screenshot
class Screenshot {
  final List<int> data;
  final int width;
  final int height;
  final DateTime timestamp;

  Screenshot({
    required this.data,
    required this.width,
    required this.height,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'size': data.length,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Represents a window
class Window {
  final String id;
  final String title;
  final String appName;
  final Rectangle bounds;
  final bool isMinimized;
  final bool isMaximized;
  final bool isActive;

  Window({
    required this.id,
    required this.title,
    required this.appName,
    required this.bounds,
    this.isMinimized = false,
    this.isMaximized = false,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'app_name': appName,
      'bounds': {
        'x': bounds.x,
        'y': bounds.y,
        'width': bounds.width,
        'height': bounds.height,
      },
      'is_minimized': isMinimized,
      'is_maximized': isMaximized,
      'is_active': isActive,
    };
  }

  @override
  String toString() {
    return 'Window(id: $id, title: "$title", app: $appName)';
  }
}
