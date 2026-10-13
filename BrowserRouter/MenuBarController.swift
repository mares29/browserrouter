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
    private let showWelcome: () -> Void

    init(settings: AppSettings, stack: BrowserStack, urlHandler: URLHandler, browsers: [Browser], showWelcome: @escaping () -> Void) {
        self.settings = settings
        self.stack = stack
        self.urlHandler = urlHandler
        self.browsers = browsers
        self.showWelcome = showWelcome
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
            button.image = Self.menuBarIcon()
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
        let isDefault = BrowserDetector.isSelfDefault()

        // Status line
        let statusLineItem = NSMenuItem(title: statusLine(isDefault: isDefault), action: nil, keyEquivalent: "")
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

        // Rules submenu
        let rulesItem = NSMenuItem(title: "Rules", action: nil, keyEquivalent: "")
        rulesItem.submenu = buildRulesSubmenu()
        menu.addItem(rulesItem)

        menu.addItem(.separator())

        // Menu Bar Display submenu
        let displayItem = NSMenuItem(title: "Menu Bar Display", action: nil, keyEquivalent: "")
        displayItem.submenu = buildDisplayModeSubmenu()
        menu.addItem(displayItem)

        menu.addItem(.separator())

        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        switch LaunchAtLogin.status {
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

        // Set as Default Browser, shown ticked and inactive once it is
        let defaultItem = NSMenuItem(
            title: isDefault ? "Default Browser" : "Set as Default Browser…",
            action: isDefault ? nil : #selector(setAsDefaultBrowser),
            keyEquivalent: ""
        )
        defaultItem.state = isDefault ? .on : .off
        defaultItem.target = self
        menu.addItem(defaultItem)

        // The welcome window again, to walk through setup
        let welcomeItem = NSMenuItem(title: "Show Welcome…", action: #selector(openWelcome), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit BrowserRouter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    /// Where links follow focus to, as resolved by URLHandler; a rule can still send a link elsewhere
    private var targetBrowser: Browser? {
        guard let bundleID = urlHandler.targetBrowser() else { return nil }
        return browsers.first { $0.bundleID == bundleID } ?? BrowserDetector.browser(withBundleID: bundleID)
    }

    private func statusLine(isDefault: Bool) -> String {
        // Links only reach BrowserRouter while it is the default browser
        guard isDefault else { return "Not your default browser" }
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

    private func buildRulesSubmenu() -> NSMenu {
        let submenu = NSMenu()

        if settings.rules.isEmpty {
            let emptyItem = NSMenuItem(title: "No Rules", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        }

        // Listed in the order they are checked
        for (index, rule) in settings.rules.enumerated() {
            let item = NSMenuItem(title: ruleTitle(rule), action: nil, keyEquivalent: "")
            item.state = rule.isEnabled ? .on : .off
            item.toolTip = rule.pattern
            item.submenu = buildRuleSubmenu(for: rule, at: index)
            submenu.addItem(item)
        }

        submenu.addItem(.separator())

        let addItem = NSMenuItem(title: "Add Rule…", action: #selector(addRule), keyEquivalent: "")
        addItem.target = self
        submenu.addItem(addItem)

        return submenu
    }

    private func buildRuleSubmenu(for rule: URLRule, at index: Int) -> NSMenu {
        let submenu = NSMenu()

        // Move Up and Move Down get no action at the ends, so they show disabled
        func addItem(_ title: String, _ action: Selector, isEnabled: Bool = true) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: isEnabled ? action : nil, keyEquivalent: "")
            item.representedObject = rule.id
            item.target = self
            submenu.addItem(item)
            return item
        }

        _ = addItem("Edit…", #selector(editRule(_:)))
        addItem("Enabled", #selector(toggleRule(_:))).state = rule.isEnabled ? .on : .off
        submenu.addItem(.separator())
        _ = addItem("Move Up", #selector(moveRuleUp(_:)), isEnabled: index > 0)
        _ = addItem("Move Down", #selector(moveRuleDown(_:)), isEnabled: index < settings.rules.count - 1)
        submenu.addItem(.separator())
        _ = addItem("Delete", #selector(deleteRule(_:)))

        return submenu
    }

    /// "github.com → Google Chrome", with long patterns shortened
    private func ruleTitle(_ rule: URLRule) -> String {
        let pattern = rule.pattern.count > 40 ? rule.pattern.prefix(39) + "…" : rule.pattern
        let match = rule.kind == .domain ? pattern : "\(rule.kind.label) “\(pattern)”"
        return "\(match) → \(browserName(rule.browserID))"
    }

    private func browserName(_ bundleID: String) -> String {
        let browser = browsers.first { $0.bundleID == bundleID } ?? BrowserDetector.browser(withBundleID: bundleID)
        return browser?.name ?? "\(bundleID) (not installed)"
    }

    /// Browsers a rule can open, keeping the rule's own browser even when detection skips it
    private func ruleBrowsers(including bundleID: String) -> [Browser] {
        guard !browsers.contains(where: { $0.bundleID == bundleID }),
              let browser = BrowserDetector.browser(withBundleID: bundleID)
        else { return browsers }
        return browsers + [browser]
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

    /// Template glyph copied in by the bundle scripts; the globe covers unbundled `swift run`
    static func menuBarIcon() -> NSImage? {
        guard let icon = Bundle.main.image(forResource: "MenuBarIconTemplate") else {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "BrowserRouter")
        }
        icon.isTemplate = true
        icon.accessibilityDescription = "BrowserRouter"
        return icon
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

    @objc private func addRule() {
        // Preselect where links go now; the user picks the rule's browser from there
        guard let browserID = urlHandler.targetBrowser() ?? browsers.first?.bundleID else { return }
        let draft = URLRule(kind: .domain, pattern: "", browserID: browserID)

        guard let rule = RuleEditor(rule: draft, browsers: ruleBrowsers(including: browserID), isNew: true).run() else { return }
        settings.rules.append(rule)
    }

    @objc private func editRule(_ sender: NSMenuItem) {
        guard let index = ruleIndex(sender) else { return }
        let rule = settings.rules[index]

        guard let edited = RuleEditor(rule: rule, browsers: ruleBrowsers(including: rule.browserID), isNew: false).run() else { return }
        settings.rules[index] = edited
    }

    @objc private func toggleRule(_ sender: NSMenuItem) {
        guard let index = ruleIndex(sender) else { return }
        settings.rules[index].isEnabled.toggle()
    }

    @objc private func moveRuleUp(_ sender: NSMenuItem) {
        guard let index = ruleIndex(sender), index > 0 else { return }
        settings.rules.swapAt(index, index - 1)
    }

    @objc private func moveRuleDown(_ sender: NSMenuItem) {
        guard let index = ruleIndex(sender), index < settings.rules.count - 1 else { return }
        settings.rules.swapAt(index, index + 1)
    }

    @objc private func deleteRule(_ sender: NSMenuItem) {
        guard let index = ruleIndex(sender) else { return }
        settings.rules.remove(at: index)
    }

    private func ruleIndex(_ sender: NSMenuItem) -> Int? {
        guard let id = sender.representedObject as? UUID else { return nil }
        return settings.rules.firstIndex { $0.id == id }
    }

    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? Int,
              let mode = MenuBarDisplayMode(rawValue: rawValue) else { return }
        settings.menuBarDisplayMode = mode
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            // Waiting for approval counts as off, so clicking it again opens System Settings
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
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

    @objc private func openWelcome() {
        showWelcome()
    }

    @objc private func setAsDefaultBrowser() {
        BrowserDetector.setSelfAsDefault { [weak self] isDefault in
            if !isDefault {
                self?.showNotDefaultAlert()
            }
        }
    }

    /// Declining macOS's prompt, or it failing, would otherwise look like nothing happened
    private func showNotDefaultAlert() {
        let current = BrowserDetector.systemDefaultBrowserName() ?? "another browser"
        let alert = NSAlert()
        alert.messageText = "BrowserRouter isn't your default browser"
        alert.informativeText = "Links open in \(current) without going through BrowserRouter. You can also choose the default web browser in System Settings › Desktop & Dock."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")
        // A menu bar app isn't frontmost, so bring the alert forward
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            BrowserDetector.openDefaultBrowserSettings()
        }
    }
}
