import AppKit
import ServiceManagement
import SleeplessCore
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private var active = false
    private var offDeadline: Date?
    private var offTimer: Timer?
    private var batteryTimer: Timer?
    private var lastAutoOff: String?
    private var signalSources: [DispatchSourceSignal] = []

    private let lowBatteryPercent = 15
    private let durations: [(label: String, seconds: TimeInterval)] = [
        ("30 minutes", 30 * 60),
        ("1 hour", 3600),
        ("2 hours", 2 * 3600),
        ("4 hours", 4 * 3600),
    ]

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        statusItem.button?.toolTip = "Sleepless"

        // If sleep is already disabled (a previous run crashed or was killed),
        // adopt that state instead of silently leaving the machine unsleepable.
        if SleepManager.isSleepDisabled() {
            active = true
            startBatteryMonitor()
        }
        updateIcon()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        installSignalHandlers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if active {
            _ = SleepManager.setSleepDisabled(false)
        }
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addInfoItem(statusDescription())

        let battery = BatteryMonitor.read()
        if let percent = battery.percent {
            let power = battery.onACPower ? (battery.charging ? "charging" : "on AC") : "on battery"
            addInfoItem("Battery \(percent)% — \(power)")
        }

        let thermal = ProcessInfo.processInfo.thermalState
        if thermal == .serious || thermal == .critical {
            addInfoItem("⚠️ Thermal pressure: \(thermal == .critical ? "critical" : "serious")")
        }

        if let lastAutoOff {
            addInfoItem("Last auto-off: \(lastAutoOff)")
        }

        menu.addItem(.separator())

        if active {
            addActionItem("Turn Off — Allow Sleep", action: #selector(turnOffClicked))
        } else {
            addActionItem("Keep Awake", action: #selector(keepAwakeIndefinitely))
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            for duration in durations {
                let item = NSMenuItem(title: duration.label, action: #selector(keepAwakeFor(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = duration.seconds
                submenu.addItem(item)
            }
            let parent = NSMenuItem(title: "Keep Awake For", action: nil, keyEquivalent: "")
            menu.addItem(parent)
            menu.setSubmenu(submenu, for: parent)
        }

        menu.addItem(.separator())

        let login = addActionItem("Launch at Login", action: #selector(toggleLaunchAtLogin))
        if Bundle.main.bundleIdentifier != nil {
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            login.isEnabled = false // running outside an .app bundle (swift run)
        }

        if !SleepManager.helperInstalled {
            addActionItem("Install Helper…", action: #selector(installHelperClicked))
        }

        menu.addItem(.separator())
        let quit = addActionItem("Quit Sleepless", action: #selector(quitClicked))
        quit.keyEquivalent = "q"
    }

    private func addInfoItem(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @discardableResult
    private func addActionItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func statusDescription() -> String {
        guard active else { return "Sleepless: Off" }
        if let offDeadline {
            let remaining = max(0, offDeadline.timeIntervalSinceNow)
            return "Sleepless: On — \(formatInterval(remaining)) left"
        }
        return "Sleepless: On"
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbol = active ? "bolt.fill" : "moon.zzz"
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Sleepless") {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = active ? "⚡︎" : "☾"
        }
        button.toolTip = active ? "Sleepless — keeping Mac awake" : "Sleepless — off"
    }

    // MARK: - Actions

    @objc private func keepAwakeIndefinitely() {
        activate(duration: nil)
    }

    @objc private func keepAwakeFor(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        activate(duration: seconds)
    }

    @objc private func turnOffClicked() {
        deactivate(reason: nil)
    }

    @objc private func installHelperClicked() {
        _ = installHelperInteractively()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError("Could not update Launch at Login: \(error.localizedDescription)")
        }
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    // MARK: - Core state changes

    private func activate(duration: TimeInterval?) {
        if !SleepManager.helperInstalled && !installHelperInteractively() {
            return
        }
        var ok = SleepManager.setSleepDisabled(true)
        if !ok {
            // Helper exists but sudo refused — sudoers rule missing or stale. Offer a reinstall.
            if installHelperInteractively() {
                ok = SleepManager.setSleepDisabled(true)
            }
        }
        guard ok else {
            showError("Could not disable sleep. Try Install Helper… from the menu, or run the install script from the project's helper folder.")
            return
        }

        active = true
        lastAutoOff = nil
        offTimer?.invalidate()
        offTimer = nil
        offDeadline = nil
        if let duration {
            offDeadline = Date().addingTimeInterval(duration)
            offTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.deactivate(reason: "timer ended")
            }
        }
        startBatteryMonitor()
        requestNotificationAuthorization()
        updateIcon()
    }

    private func deactivate(reason: String?) {
        _ = SleepManager.setSleepDisabled(false)
        active = false
        offTimer?.invalidate()
        offTimer = nil
        offDeadline = nil
        batteryTimer?.invalidate()
        batteryTimer = nil
        if let reason {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            lastAutoOff = "\(reason) at \(formatter.string(from: Date()))"
            notify(title: "Sleep re-enabled", body: "Keep-awake turned off: \(reason).")
        }
        updateIcon()
    }

    // MARK: - Safety monitors

    private func startBatteryMonitor() {
        batteryTimer?.invalidate()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer
    }

    private func checkBattery() {
        guard active else { return }
        let battery = BatteryMonitor.read()
        if battery.shouldAutoOff(belowPercent: lowBatteryPercent), let percent = battery.percent {
            deactivate(reason: "battery low (\(percent)%)")
        }
    }

    @objc private func thermalStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.active else { return }
            if ProcessInfo.processInfo.thermalState == .critical {
                self.deactivate(reason: "critical thermal pressure")
            }
        }
    }

    /// Restore normal sleep on SIGTERM/SIGINT/SIGHUP, not just clean quits.
    private func installSignalHandlers() {
        for sig in [SIGINT, SIGTERM, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: - Helper install & UI feedback

    private func installHelperInteractively() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Install privileged helper?"
        alert.informativeText = """
        Keeping the Mac awake with the lid closed requires root (pmset disablesleep). \
        This one-time step installs a small root-owned helper script and a sudoers rule \
        scoped to exactly that script, so future toggles are instant. \
        You'll be asked for your administrator password.
        """
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        let ok = SleepManager.installHelper()
        if !ok {
            showError("Helper installation failed or was cancelled.")
        }
        return ok
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "Sleepless"
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Notifications

    private func requestNotificationAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
