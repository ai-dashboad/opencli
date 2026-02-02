#!/usr/bin/env swift

import Cocoa
import Foundation
import UserNotifications

// MARK: - Ollama Model Manager
class OllamaManager {
    static let shared = OllamaManager()

    struct Model {
        let name: String
        let size: String?
        let modified: Date?
        var isInstalled: Bool
    }

    // 推荐的模型列表
    static let recommendedModels = [
        ("qwen2.5:latest", "🇨🇳 通义千问 (强大中文支持)", "7.6GB"),
        ("llama3.2:latest", "🦙 Llama 3.2 (Meta)", "2GB"),
        ("gemma2:2b", "💎 Gemma 2 (Google)", "1.6GB"),
        ("mistral:latest", "⚡ Mistral (快速)", "4.1GB"),
        ("codellama:7b", "👨‍💻 CodeLlama (代码专用)", "3.8GB"),
    ]

    var currentModel: String {
        get { UserDefaults.standard.string(forKey: "selectedModel") ?? "qwen2.5:latest" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedModel") }
    }

    func checkOllamaInstalled() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["which", "ollama"]
        task.standardOutput = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    func getInstalledModels(completion: @escaping ([Model]) -> Void) {
        guard checkOllamaInstalled() else {
            completion([])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = ["ollama", "list"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                var models: [Model] = []
                let lines = output.components(separatedBy: "\n")

                // 跳过表头，解析模型列表
                for line in lines.dropFirst() {
                    let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                    if parts.count >= 2 {
                        let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
                        let size = parts.count > 1 ? String(parts[1]) : nil

                        if !name.isEmpty {
                            models.append(Model(name: name, size: size, modified: nil, isInstalled: true))
                        }
                    }
                }

                DispatchQueue.main.async {
                    completion(models)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    func pullModel(_ modelName: String, progress: @escaping (String) -> Void, completion: @escaping (Bool) -> Void) {
        guard checkOllamaInstalled() else {
            completion(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = ["ollama", "pull", modelName]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            // 实时读取输出
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    DispatchQueue.main.async {
                        progress(output)
                    }
                }
            }

            do {
                try task.run()
                task.waitUntilExit()

                DispatchQueue.main.async {
                    completion(task.terminationStatus == 0)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    func installOllama(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = ["brew", "install", "ollama"]

            do {
                try task.run()
                task.waitUntilExit()

                DispatchQueue.main.async {
                    completion(task.terminationStatus == 0)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}

// MARK: - Status Bar Controller
class StatusBarController: NSObject {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var webSocket: URLSessionWebSocketTask?
    private var installedModels: [OllamaManager.Model] = []
    private var downloadWindow: NSWindow?

    private var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }

    override init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()

        super.init()

        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            notificationsEnabled = true
        }

        setupMenuBar()
        setupNotifications()
        connectWebSocket()
        updateStatus()

        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.updateStatus()
        }
    }

    func setupMenuBar() {
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
                self?.receiveMessage()

            case .failure(let error):
                print("⚠️  WebSocket error: \(error)")
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
        // Status
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

        // AI Model Selection
        buildAIModelMenu()

        menu.addItem(NSMenuItem.separator())

        // Notifications toggle
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

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func buildAIModelMenu() {
        let aiMenuItem = NSMenuItem(title: "🤖 AI Models", action: nil, keyEquivalent: "")
        let aiSubmenu = NSMenu()

        let ollamaInstalled = OllamaManager.shared.checkOllamaInstalled()

        if !ollamaInstalled {
            // Ollama 未安装 - 显示安装提示
            let installItem = NSMenuItem(title: "📥 Install Ollama First", action: #selector(installOllama), keyEquivalent: "")
            installItem.target = self
            aiSubmenu.addItem(installItem)

            aiSubmenu.addItem(NSMenuItem.separator())
        } else {
            // Ollama 已安装 - 显示当前模型
            let currentModel = OllamaManager.shared.currentModel
            let currentItem = NSMenuItem(title: "✅ Current: \(currentModel)", action: nil, keyEquivalent: "")
            currentItem.isEnabled = false
            aiSubmenu.addItem(currentItem)

            aiSubmenu.addItem(NSMenuItem.separator())
        }

        // 始终显示推荐模型列表
        let recommendedItem = NSMenuItem(title: "推荐模型:", action: nil, keyEquivalent: "")
        recommendedItem.isEnabled = false
        aiSubmenu.addItem(recommendedItem)

        for (modelName, description, size) in OllamaManager.recommendedModels {
            if ollamaInstalled {
                let currentModel = OllamaManager.shared.currentModel
                let isSelected = modelName == currentModel
                let title = isSelected ? "✓ \(description)" : "\(description)"
                let item = NSMenuItem(title: title, action: #selector(selectModel(_:)), keyEquivalent: "")
                item.representedObject = modelName
                item.target = self
                item.state = isSelected ? .on : .off
                aiSubmenu.addItem(item)
            } else {
                // Ollama 未安装，显示灰色不可点击的项
                let item = NSMenuItem(title: "\(description)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                aiSubmenu.addItem(item)
            }

            // 添加大小说明
            let sizeItem = NSMenuItem(title: "  Size: \(size)", action: nil, keyEquivalent: "")
            sizeItem.isEnabled = false
            sizeItem.indentationLevel = 1
            aiSubmenu.addItem(sizeItem)
        }

        if ollamaInstalled {
            aiSubmenu.addItem(NSMenuItem.separator())

            let manageItem = NSMenuItem(title: "📦 Manage Models...", action: #selector(manageModels), keyEquivalent: "")
            manageItem.target = self
            aiSubmenu.addItem(manageItem)
        }

        aiMenuItem.submenu = aiSubmenu
        menu.addItem(aiMenuItem)
    }

    func buildOfflineMenu() {
        let statusItem = NSMenuItem(title: "🔴 OpenCLI is offline", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // AI Models (仍然可以配置)
        buildAIModelMenu()

        menu.addItem(NSMenuItem.separator())

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

    @objc func installOllama() {
        let alert = NSAlert()
        alert.messageText = "Install Ollama?"
        alert.informativeText = "This will install Ollama using Homebrew. Make sure you have Homebrew installed."
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            showProgressWindow(title: "Installing Ollama...", message: "Please wait while Ollama is being installed.")

            OllamaManager.shared.installOllama { success in
                self.closeProgressWindow()

                let resultAlert = NSAlert()
                if success {
                    resultAlert.messageText = "✅ Ollama Installed"
                    resultAlert.informativeText = "Ollama has been successfully installed!"
                } else {
                    resultAlert.messageText = "❌ Installation Failed"
                    resultAlert.informativeText = "Please install Ollama manually:\nbrew install ollama"
                }
                resultAlert.runModal()
                self.updateStatus()
            }
        }
    }

    @objc func selectModel(_ sender: NSMenuItem) {
        guard let modelName = sender.representedObject as? String else { return }

        // 检查模型是否已安装
        OllamaManager.shared.getInstalledModels { models in
            let isInstalled = models.contains { $0.name.hasPrefix(modelName.replacingOccurrences(of: ":latest", with: "")) }

            if isInstalled {
                // 直接切换
                OllamaManager.shared.currentModel = modelName
                self.sendNotification(
                    title: "✅ Model Selected",
                    body: "Now using: \(modelName)"
                )
                self.updateStatus()
            } else {
                // 需要下载
                let alert = NSAlert()
                alert.messageText = "Download Model?"
                alert.informativeText = "Model '\(modelName)' is not installed. Download it now?"
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    self.downloadModel(modelName)
                }
            }
        }
    }

    func downloadModel(_ modelName: String) {
        showProgressWindow(title: "Downloading \(modelName)", message: "This may take a while...")

        OllamaManager.shared.pullModel(modelName, progress: { output in
            // 更新进度窗口
            self.updateProgressWindow(message: output)
        }, completion: { success in
            self.closeProgressWindow()

            if success {
                OllamaManager.shared.currentModel = modelName
                self.sendNotification(
                    title: "✅ Model Downloaded",
                    body: "\(modelName) is ready to use!"
                )
            } else {
                let alert = NSAlert()
                alert.messageText = "❌ Download Failed"
                alert.informativeText = "Failed to download \(modelName)"
                alert.runModal()
            }

            self.updateStatus()
        })
    }

    func showProgressWindow(title: String, message: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.isReleasedWhenClosed = false

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: message)
        label.alignment = .center

        let progressBar = NSProgressIndicator()
        progressBar.style = .bar
        progressBar.isIndeterminate = true
        progressBar.startAnimation(nil)

        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(progressBar)

        window.contentView = stackView
        window.makeKeyAndOrderFront(nil)

        self.downloadWindow = window
    }

    func updateProgressWindow(message: String) {
        // 可以更新进度窗口的文本
    }

    func closeProgressWindow() {
        downloadWindow?.close()
        downloadWindow = nil
    }

    @objc func manageModels() {
        NSWorkspace.shared.open(URL(string: "https://ollama.com/library")!)
    }

    @objc func toggleNotifications() {
        notificationsEnabled.toggle()
        updateStatus()

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
