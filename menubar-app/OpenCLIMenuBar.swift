#!/usr/bin/env swift

import Cocoa
import Foundation
import UserNotifications

class StatusBarController: NSObject {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var webSocket: URLSessionWebSocketTask?
    private var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }

    override init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()

        super.init()

        // Default to notifications enabled
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            notificationsEnabled = true
        }

        setupMenuBar()
        setupNotifications()
        connectWebSocket()
        updateStatus()

        // Update status every 30 seconds (减少频率)
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.updateStatus()
        }
    }

    func setupMenuBar() {
        // Set icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "OpenCLI")
            button.image?.isTemplate = true
        }

        statusItem.menu = menu
    }

    func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("⚠️  Notification authorization error: \(error)")
            }
        }
    }

    // WebSocket 连接监听任务完成事件
    func connectWebSocket() {
        let url = URL(string: "ws://localhost:9876")!
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        receiveMessage()
    }

    func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self?.receiveMessage()

            case .failure(let error):
                print("⚠️  WebSocket error: \(error)")
                // Reconnect after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.connectWebSocket()
                }
            }
        }
    }

    func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        // 只在任务更新时发送通知
        if type == "task_update" {
            let status = json["status"] as? String ?? "unknown"
            let taskType = json["task_type"] as? String ?? "task"

            if status == "completed" || status == "failed" {
                sendNotification(
                    title: status == "completed" ? "✅ 任务完成" : "❌ 任务失败",
                    body: "任务类型: \(taskType)"
                )
            }
        }
    }

    func sendNotification(title: String, body: String) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️  Failed to send notification: \(error)")
            }
        }
    }

    func updateStatus() {
        menu.removeAllItems()

        // Fetch status from daemon
        let url = URL(string: "http://localhost:9875/status")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let daemon = json["daemon"] as? [String: Any],
                   let mobile = json["mobile"] as? [String: Any] {
                    self.buildMenu(daemon: daemon, mobile: mobile)
                } else {
                    self.buildOfflineMenu()
                }
            }
        }
        task.resume()
    }

    func buildMenu(daemon: [String: Any], mobile: [String: Any]) {
        // Status header
        let statusItem = NSMenuItem(title: "🟢 OpenCLI is running", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Stats
        if let version = daemon["version"] as? String {
            let versionItem = NSMenuItem(title: "Version: \(version)", action: nil, keyEquivalent: "")
            versionItem.isEnabled = false
            menu.addItem(versionItem)
        }

        if let uptime = daemon["uptime_seconds"] as? Int {
            let hours = uptime / 3600
            let minutes = (uptime % 3600) / 60
            let uptimeItem = NSMenuItem(title: "Uptime: \(hours)h \(minutes)m", action: nil, keyEquivalent: "")
            uptimeItem.isEnabled = false
            menu.addItem(uptimeItem)
        }

        if let memory = daemon["memory_mb"] as? Double {
            let memoryItem = NSMenuItem(title: String(format: "Memory: %.1f MB", memory), action: nil, keyEquivalent: "")
            memoryItem.isEnabled = false
            menu.addItem(memoryItem)
        }

        if let clients = mobile["connected_clients"] as? Int {
            let clientsItem = NSMenuItem(title: "Mobile Clients: \(clients)", action: nil, keyEquivalent: "")
            clientsItem.isEnabled = false
            menu.addItem(clientsItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 通知开关
        let notifItem = NSMenuItem(
            title: notificationsEnabled ? "🔔 通知: 开启" : "🔕 通知: 关闭",
            action: #selector(toggleNotifications),
            keyEquivalent: "n"
        )
        notifItem.target = self
        notifItem.state = notificationsEnabled ? .on : .off
        menu.addItem(notifItem)

        menu.addItem(NSMenuItem.separator())

        // Actions
        let dashboardItem = NSMenuItem(title: "📊 Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        let webUIItem = NSMenuItem(title: "🌐 Open Web UI", action: #selector(openWebUI), keyEquivalent: "w")
        webUIItem.target = self
        menu.addItem(webUIItem)

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "🔄 Refresh", action: #selector(refreshStatus), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit OpenCLI Menu", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func buildOfflineMenu() {
        let statusItem = NSMenuItem(title: "🔴 OpenCLI is offline", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // 通知开关（即使离线也可以切换）
        let notifItem = NSMenuItem(
            title: notificationsEnabled ? "🔔 通知: 开启" : "🔕 通知: 关闭",
            action: #selector(toggleNotifications),
            keyEquivalent: "n"
        )
        notifItem.target = self
        notifItem.state = notificationsEnabled ? .on : .off
        menu.addItem(notifItem)

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "🔄 Refresh", action: #selector(refreshStatus), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc func toggleNotifications() {
        notificationsEnabled.toggle()
        updateStatus() // 刷新菜单显示

        // 显示确认提示
        sendNotification(
            title: "通知设置已更新",
            body: notificationsEnabled ? "任务完成通知已开启" : "任务完成通知已关闭"
        )
    }

    @objc func openDashboard() {
        NSWorkspace.shared.open(URL(string: "http://localhost:9875/status")!)
    }

    @objc func openWebUI() {
        NSWorkspace.shared.open(URL(string: "http://localhost:3000")!)
    }

    @objc func refreshStatus() {
        updateStatus()
    }

    @objc func quit() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        NSApplication.shared.terminate(self)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}

// Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
