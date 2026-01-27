# Native Menu Design

## Goal

Replace NSPopover with native NSMenu for simpler, more macOS-native UI.

## Design Decisions

- **UI approach:** Native NSMenu (not popover)
- **Menu items:** Text only, no browser icons
- **Settings window:** Remove entirely - all settings in menu
- **Menu bar icon:** Keep globe icon

---

## Menu Structure

```
Opening links in Safari       (status, disabled)
─────────────────────────────
Tracked Browsers          >   (submenu, checkmarks)
  ✓ Safari
  ✓ Chrome
    Firefox
─────────────────────────────
Fallback Browser          >   (submenu, radio)
  ● Safari
    Chrome
─────────────────────────────
Menu Bar Display          >   (submenu, radio)
  ● Icon only
    Icon + letter
    Icon + name
─────────────────────────────
Launch at Login           ✓   (toggle)
Set as Default Browser
─────────────────────────────
Quit BrowserRouter       ⌘Q
```

---

## Implementation

### MenuBarController Changes

Replace popover-based approach with NSMenu:

```swift
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let settings: AppSettings
    private let stack: BrowserStack
    private var browsers: [Browser] = []

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "BrowserRouter")
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        // Status line
        let statusItem = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // Tracked Browsers submenu
        let trackedMenu = NSMenu()
        for browser in browsers {
            let item = NSMenuItem(title: browser.name, action: #selector(toggleTracked(_:)), keyEquivalent: "")
            item.representedObject = browser.bundleID
            item.state = settings.trackedBrowsers.contains(browser.bundleID) ? .on : .off
            item.target = self
            trackedMenu.addItem(item)
        }
        let trackedItem = NSMenuItem(title: "Tracked Browsers", action: nil, keyEquivalent: "")
        trackedItem.submenu = trackedMenu
        menu.addItem(trackedItem)

        // ... similar for Fallback Browser, Menu Bar Display

        menu.addItem(.separator())

        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        // Set as Default
        menu.addItem(NSMenuItem(title: "Set as Default Browser", action: #selector(setAsDefault), keyEquivalent: ""))

        menu.addItem(.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit BrowserRouter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem?.menu = menu
    }
}
```

### Files to Delete

- `SettingsView.swift` - Replaced by menu
- `SettingsWindowView.swift` - No longer needed

### Files to Modify

- `MenuBarController.swift` - Complete rewrite for NSMenu
- `App.swift` - Remove SettingsView setup, simplify initialization

### Files to Keep (unchanged)

- `AppSettings.swift` (Settings.swift)
- `BrowserStack.swift`
- `BrowserDetector.swift`
- `FocusMonitor.swift`
- `URLHandler.swift`
- `FirstLaunchView.swift`

---

## Menu Rebuild Triggers

Menu needs rebuilding when:
- Browser stack changes (status text updates)
- Settings change (checkmarks update)
- Browsers rescanned

Use `NSMenuDelegate` with `menuNeedsUpdate(_:)` for lazy rebuilding.
