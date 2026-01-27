# Menu Bar Display Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show current browser info next to menu bar icon with configurable display modes.

**Architecture:** Add `MenuBarDisplayMode` enum to AppSettings, wire MenuBarController to observe BrowserStack and AppSettings via Combine, update status item title reactively.

**Tech Stack:** Swift, SwiftUI, Combine, AppKit (NSStatusItem)

---

## Task 1: Add MenuBarDisplayMode to AppSettings

**Files:**
- Modify: `BrowserRouter/Settings.swift`

**Step 1: Add enum before class definition**

Add at line 3 (before `final class AppSettings`):

```swift
enum MenuBarDisplayMode: Int, CaseIterable {
    case iconOnly = 0
    case iconAndLetter = 1
    case iconAndName = 2

    var label: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .iconAndLetter: return "Icon + letter"
        case .iconAndName: return "Icon + name"
        }
    }
}
```

**Step 2: Add key constant**

Add inside `Keys` enum:

```swift
static let menuBarDisplayMode = "menuBarDisplayMode"
```

**Step 3: Add published property**

Add after `fallbackBrowser` property:

```swift
@Published var menuBarDisplayMode: MenuBarDisplayMode {
    didSet { defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode) }
}
```

**Step 4: Initialize in init()**

Add at end of `init()`:

```swift
self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: defaults.integer(forKey: Keys.menuBarDisplayMode)) ?? .iconOnly
```

**Step 5: Verify build**

Run: `swift build`
Expected: Build succeeds

**Step 6: Commit**

```bash
git add BrowserRouter/Settings.swift
git commit -m "feat: add MenuBarDisplayMode to AppSettings"
```

---

## Task 2: Update MenuBarController to Accept Dependencies

**Files:**
- Modify: `BrowserRouter/MenuBarController.swift`

**Step 1: Add imports and properties**

Replace lines 1-8 with:

```swift
import SwiftUI
import AppKit
import Combine

final class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    private let settings: AppSettings
    private let stack: BrowserStack
    private let browsers: [Browser]

    @Published var currentBrowser: String?
```

**Step 2: Add initializer**

Add after properties, before `setup()`:

```swift
init(settings: AppSettings, stack: BrowserStack, browsers: [Browser]) {
    self.settings = settings
    self.stack = stack
    self.browsers = browsers
    super.init()
    setupObservers()
}
```

**Step 3: Add setupObservers method**

Add after `init`:

```swift
private func setupObservers() {
    // Observe browser stack changes
    stack.$browsers
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.updateTitle() }
        .store(in: &cancellables)

    // Observe display mode changes
    settings.$menuBarDisplayMode
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.updateTitle() }
        .store(in: &cancellables)
}
```

**Step 4: Replace updateIcon with updateTitle**

Replace `updateIcon(for:)` method with:

```swift
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
```

**Step 5: Call updateTitle after setup**

Add at end of `setup()` method:

```swift
updateTitle()
```

**Step 6: Verify build**

Run: `swift build`
Expected: FAIL - AppDelegate needs updating

**Step 7: Commit (partial)**

```bash
git add BrowserRouter/MenuBarController.swift
git commit -m "feat: add Combine observers to MenuBarController"
```

---

## Task 3: Update AppDelegate Wiring

**Files:**
- Modify: `BrowserRouter/App.swift`

**Step 1: Store detected browsers**

Add property after `firstLaunchWindow`:

```swift
private var detectedBrowsers: [Browser] = []
```

**Step 2: Update applicationDidFinishLaunching**

Replace lines 24-31 with:

```swift
settings = AppSettings()
stack = BrowserStack()
detectedBrowsers = BrowserDetector.detectBrowsers()

focusMonitor = FocusMonitor(settings: settings, stack: stack)
urlHandler = URLHandler(settings: settings, stack: stack)
menuBarController = MenuBarController(settings: settings, stack: stack, browsers: detectedBrowsers)

let settingsView = SettingsView(settings: settings, stack: stack)
menuBarController.setup(settingsView: settingsView)
```

**Step 3: Verify build**

Run: `swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BrowserRouter/App.swift
git commit -m "feat: wire MenuBarController with settings and stack"
```

---

## Task 4: Add Display Mode Picker to SettingsView

**Files:**
- Modify: `BrowserRouter/SettingsView.swift`

**Step 1: Add displayModePicker computed property**

Add after `launchAtLoginToggle` (after line 73):

```swift
private var displayModePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Menu bar display:")
            .font(.subheadline)

        Picker("", selection: $settings.menuBarDisplayMode) {
            ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }
}
```

**Step 2: Add to body**

Replace lines 16-18 with:

```swift
Divider()
displayModePicker
Divider()
launchAtLoginToggle
Divider()
```

**Step 3: Verify build**

Run: `swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BrowserRouter/SettingsView.swift
git commit -m "feat: add display mode picker to SettingsView"
```

---

## Task 5: Build, Test, and Final Commit

**Step 1: Full rebuild**

Run: `swift build -c release`
Expected: Build succeeds

**Step 2: Rebuild app bundle**

Run: `./scripts/bundle.sh`
Expected: App installed to ~/Applications

**Step 3: Manual test**

1. Open BrowserRouter.app
2. Click menu bar icon
3. Change "Menu bar display" to "Icon + letter"
4. Switch to Safari, then back
5. Verify menu bar shows "🌐 S"
6. Change to "Icon + name"
7. Verify menu bar shows "🌐 Safari"
8. Change to "Icon only"
9. Verify only globe icon shows

**Step 4: Push changes**

```bash
git push
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Add `MenuBarDisplayMode` enum and setting |
| 2 | Wire `MenuBarController` with Combine observers |
| 3 | Update `AppDelegate` to pass dependencies |
| 4 | Add picker to `SettingsView` |
| 5 | Build, test, push |
