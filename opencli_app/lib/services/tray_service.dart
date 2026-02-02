import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Service to handle system tray events
class TrayService with TrayListener {
  /// Initialize the tray service
  void init() {
    trayManager.addListener(this);
  }

  /// Dispose the tray service
  void dispose() {
    trayManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    // Show window when tray icon is clicked
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Show context menu on right-click
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        // Show and focus the window
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'exit':
        // Exit the application
        await windowManager.destroy();
        break;
    }
  }
}
