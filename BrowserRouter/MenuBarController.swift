import AppKit
import Combine
import os
import ServiceManagement

final class MenuBarController: NSObject, NSMenuDelegate {
    private static let logger = Logger(subsystem: "com.browserrouter.app", category: "MenuBarController")

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    private let settings: AppSettings
    private let stack: BrowserStack
    private let urlHandler: URLHandler
    private var browsers: [Browser]

    init(settings: AppSettings, stack: BrowserStack, urlHandler: URLHandler, browsers: [Browser]) {
        self.settings = settings
        self.stack = stack
        self.urlHandler = urlHandler
        self.browsers = browsers
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        // The target browser changes with focus, settings, and browsers launching or quitting.
        // receive(on:) defers the update until the @Published value has actually been set.
        let workspace = NSWorkspace.shared.notificationCenter
        Publishers.MergeMany(
            stack.objectWillChange.eraseToAnyPublisher(),
            settings.objectWillChange.eraseToAnyPublisher(),
            workspace.publisher(for: NSWorkspace.didLaunchApplicationNotification).map { _ in }.eraseToAnyPublisher(),
            workspace.publisher(for: NSWorkspace.didTerminateApplicationNotification).map { _ in }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.updateTitle() }
        .store(in: &cancellables)
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "BrowserRouter")
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        updateTitle()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Re-scan so browsers installed or removed since launch show up
        browsers = addingPickedBrowsers(to: BrowserDetector.detectBrowsers())
        menu.removeAllItems()
        buildMenu(menu)
    }

    /// Apps the user already tracks or falls back to stay listed even when detection
    /// skips them, so they can still be seen and unticked
    private func addingPickedBrowsers(to detected: [Browser]) -> [Browser] {
        var seen = Set(detected.map(\.bundleID))
        let picked = settings.trackedBrowsers + [settings.fallbackBrowser].compactMap { $0 }
        let missing = picked.filter { seen.insert($0).inserted }.compactMap(BrowserDetector.browser(withBundleID:))
        return detected + missing
    }

    private func buildMenu(_ menu: NSMenu) {
        // Status line
        let statusLineItem = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        statusLineItem.isEnabled = false
        menu.addItem(statusLineItem)

        menu.addItem(.separator())

        // Tracked Browsers submenu
        let trackedItem = NSMenuItem(title: "Tracked Browsers", action: nil, keyEquivalent: "")
        trackedItem.submenu = buildTrackedBrowsersSubmenu()
        menu.addItem(trackedItem)

        // Fallback Browser submenu
        let fallbackItem = NSMenuItem(title: "Fallback Browser", action: nil, keyEquivalent: "")
        fallbackItem.submenu = buildFallbackBrowserSubmenu()
        menu.addItem(fallbackItem)

        menu.addItem(.separator())

        // Menu Bar Display submenu
        let displayItem = NSMenuItem(title: "Menu Bar Display", action: nil, keyEquivalent: "")
        displayItem.submenu = buildDisplayModeSubmenu()
        menu.addItem(displayItem)

        menu.addItem(.separator())

        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        switch SMAppService.mainApp.status {
        case .enabled:
            loginItem.state = .on
        case .requiresApproval:
            // Registered, but waiting for the user to allow it in System Settings
            loginItem.state = .mixed
            loginItem.toolTip = "Needs approval in System Settings › General › Login Items"
        default:
            loginItem.state = .off
        }
        loginItem.target = self
        menu.addItem(loginItem)

        // Set as Default Browser
        let defaultItem = NSMenuItem(title: "Set as Default Browser", action: #selector(setAsDefaultBrowser), keyEquivalent: "")
        defaultItem.target = self
        menu.addItem(defaultItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit BrowserRouter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    /// The browser the next link will open in, as resolved by URLHandler
    private var targetBrowser: Browser? {
        guard let bundleID = urlHandler.targetBrowser() else { return nil }
        return browsers.first { $0.bundleID == bundleID } ?? BrowserDetector.browser(withBundleID: bundleID)
    }

    private func statusLine() -> String {
        if let browser = targetBrowser {
            return "Opening links in \(browser.name)"
        }
        return "No browser selected"
    }

    private func buildTrackedBrowsersSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for browser in browsers {
            let item = NSMenuItem(title: browser.name, action: #selector(toggleTrackedBrowser(_:)), keyEquivalent: "")
            item.representedObject = browser.bundleID
            item.state = settings.trackedBrowsers.contains(browser.bundleID) ? .on : .off
            item.target = self
            submenu.addItem(item)
        }
        return submenu
    }

    private func buildFallbackBrowserSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for browser in browsers {
            let item = NSMenuItem(title: browser.name, action: #selector(setFallbackBrowser(_:)), keyEquivalent: "")
            item.representedObject = browser.bundleID
            item.state = settings.fallbackBrowser == browser.bundleID ? .on : .off
            item.target = self
            submenu.addItem(item)
        }
        return submenu
    }

    private func buildDisplayModeSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for mode in MenuBarDisplayMode.allCases {
            let item = NSMenuItem(title: mode.label, action: #selector(setDisplayMode(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue
            item.state = settings.menuBarDisplayMode == mode ? .on : .off
            item.target = self
            submenu.addItem(item)
        }
        return submenu
    }

    private func updateTitle() {
        guard let button = statusItem?.button else { return }

        guard let browser = targetBrowser else {
            button.title = ""
            return
        }

        switch settings.menuBarDisplayMode {
        case .iconOnly:
            button.title = ""
        case .iconAndLetter:
            button.title = " \(browser.name.prefix(1))"
        case .iconAndName:
            button.title = " \(browser.name)"
        }
    }

    // MARK: - Actions

    @objc private func toggleTrackedBrowser(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        if settings.trackedBrowsers.contains(bundleID) {
            settings.trackedBrowsers.removeAll { $0 == bundleID }
        } else {
            settings.trackedBrowsers.append(bundleID)
        }
    }

    @objc private func setFallbackBrowser(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        settings.fallbackBrowser = bundleID
    }

    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? Int,
              let mode = MenuBarDisplayMode(rawValue: rawValue) else { return }
        settings.menuBarDisplayMode = mode
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled:
                try SMAppService.mainApp.unregister()
            case .requiresApproval:
                // Already registered; only the user can approve it
                SMAppService.openSystemSettingsLoginItems()
            default:
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            Self.logger.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
            showLoginItemError(error)
        }
    }

    private func showLoginItemError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn't update Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        // A menu bar app isn't frontmost, so bring the alert forward
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func setAsDefaultBrowser() {
        BrowserDetector.setSelfAsDefault()
    }
}
