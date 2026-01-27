# Native Menu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace NSPopover with native NSMenu for simpler, more macOS-native UI.

**Architecture:** MenuBarController becomes NSMenuDelegate, builds menu dynamically. Remove SettingsView and SettingsWindowView. All settings accessible via menu items and submenus.

**Tech Stack:** AppKit (NSMenu, NSMenuItem, NSMenuDelegate), ServiceManagement

---

### Task 1: Rewrite MenuBarController with NSMenu

**Files:**
- Modify: `BrowserRouter/BrowserRouter/MenuBarController.swift`

**Step 1: Replace entire MenuBarController with NSMenu-based implementation**

```swift
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
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build fails - App.swift still references old setup method

**Step 3: Commit partial progress**

```bash
git add BrowserRouter/BrowserRouter/MenuBarController.swift
git commit -m "feat: rewrite MenuBarController to use native NSMenu"
```

---

### Task 2: Update App.swift

**Files:**
- Modify: `BrowserRouter/BrowserRouter/App.swift`

**Step 1: Simplify AppDelegate to use new MenuBarController**

Replace the setup code in `applicationDidFinishLaunching`:

Find:
```swift
        let settingsView = SettingsView(settings: settings, stack: stack) {
            self.menuBarController.openSettingsWindow()
        }
        menuBarController.setup(settingsView: settingsView)
```

Replace with:
```swift
        menuBarController.setup()
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BrowserRouter/BrowserRouter/App.swift
git commit -m "feat: simplify App.swift for native menu"
```

---

### Task 3: Delete SettingsView.swift

**Files:**
- Delete: `BrowserRouter/BrowserRouter/SettingsView.swift`

**Step 1: Remove the file**

```bash
rm BrowserRouter/BrowserRouter/SettingsView.swift
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove SettingsView (replaced by native menu)"
```

---

### Task 4: Delete SettingsWindowView.swift

**Files:**
- Delete: `BrowserRouter/BrowserRouter/SettingsWindowView.swift`

**Step 1: Remove the file**

```bash
rm BrowserRouter/BrowserRouter/SettingsWindowView.swift
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove SettingsWindowView (replaced by native menu)"
```

---

### Task 5: Build and Install App Bundle

**Step 1: Run bundle script**

Run: `./scripts/bundle.sh`
Expected: App built and installed to ~/Applications

**Step 2: Verify installation**

Run: `ls -la ~/Applications/BrowserRouter.app/Contents/MacOS/`
Expected: BrowserRouter executable exists

**Step 3: Commit any remaining changes**

```bash
git status
git add -A
git commit -m "feat: complete native menu implementation" --allow-empty
```

---

### Task 6: Push to Remote

**Step 1: Push changes**

Run: `git push`
Expected: Changes pushed to origin/main

---

## Verification Checklist

After all tasks complete:
- [ ] Menu appears when clicking globe icon
- [ ] Status line shows current browser
- [ ] Tracked Browsers submenu has checkmarks
- [ ] Fallback Browser submenu has radio selection
- [ ] Menu Bar Display submenu works
- [ ] Launch at Login toggles
- [ ] Set as Default Browser works
- [ ] Quit with ⌘Q works
- [ ] App builds and installs successfully
