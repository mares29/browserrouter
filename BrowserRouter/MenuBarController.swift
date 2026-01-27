import AppKit
import Combine
import ServiceManagement

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    private let settings: AppSettings
    private let stack: BrowserStack
    private var browsers: [Browser]

    init(settings: AppSettings, stack: BrowserStack, browsers: [Browser]) {
        self.settings = settings
        self.stack = stack
        self.browsers = browsers
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        stack.$browsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)

        settings.$menuBarDisplayMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTitle() }
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

    func updateBrowsers(_ browsers: [Browser]) {
        self.browsers = browsers
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        buildMenu(menu)
    }

    private func buildMenu(_ menu: NSMenu) {
        // Status line
        let statusText = statusLine()
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

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
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
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

    private func statusLine() -> String {
        if let bundleID = stack.mostRecent,
           let browser = browsers.first(where: { $0.bundleID == bundleID }) {
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

        guard let bundleID = stack.mostRecent,
              let browser = browsers.first(where: { $0.bundleID == bundleID }) else {
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
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }

    @objc private func setAsDefaultBrowser() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID as CFString)
    }
}
