# Apple-Style Design Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign BrowserRouter UI to match macOS Control Center / System Settings visual language.

**Architecture:** Popover becomes compact browser list with vibrancy. Settings move to separate System Settings-style window. Browser struct gains icon property loaded from app bundles.

**Tech Stack:** SwiftUI, AppKit (NSWorkspace for icons, NSWindow for settings)

---

### Task 1: Add Icon to Browser Struct

**Files:**
- Modify: `BrowserRouter/BrowserDetector.swift:4-10`

**Step 1: Update Browser struct to include icon**

```swift
struct Browser: Identifiable, Equatable, Hashable {
    let bundleID: String
    let name: String
    let path: URL
    let icon: NSImage

    var id: String { bundleID }

    // Hashable conformance - exclude icon from hash
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }

    static func == (lhs: Browser, rhs: Browser) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
```

**Step 2: Update detectBrowsers() to load icons**

In the for loop, after getting name, add:

```swift
let icon = NSWorkspace.shared.icon(forFile: appURL.path)
icon.size = NSSize(width: 20, height: 20)

browsers.append(Browser(bundleID: bundleID, name: name, path: appURL, icon: icon))
```

**Step 3: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BrowserRouter/BrowserDetector.swift
git commit -m "feat: add icon property to Browser struct"
```

---

### Task 2: Create SettingsWindowView

**Files:**
- Create: `BrowserRouter/BrowserRouter/SettingsWindowView.swift`

**Step 1: Create new settings window view file**

```swift
import SwiftUI
import ServiceManagement

struct SettingsWindowView: View {
    @ObservedObject var settings: AppSettings
    @State private var detectedBrowsers: [Browser] = []
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Picker("Fallback Browser", selection: $settings.fallbackBrowser) {
                    ForEach(detectedBrowsers) { browser in
                        HStack {
                            Image(nsImage: browser.icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(browser.name)
                        }
                        .tag(browser.bundleID as String?)
                    }
                }

                Picker("Menu Bar Display", selection: $settings.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        toggleLaunchAtLogin(newValue)
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                ))
            }

            Section("Actions") {
                HStack {
                    Spacer()
                    Button("Rescan Browsers") {
                        detectedBrowsers = BrowserDetector.detectBrowsers()
                    }
                    Spacer()
                }

                HStack {
                    Spacer()
                    Button("Set as Default Browser") {
                        setAsDefaultBrowser()
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 250)
        .onAppear {
            detectedBrowsers = BrowserDetector.detectBrowsers()
        }
    }

    private func setAsDefaultBrowser() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID as CFString)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BrowserRouter/BrowserRouter/SettingsWindowView.swift
git commit -m "feat: add System Settings-style settings window view"
```

---

### Task 3: Add Settings Window to MenuBarController

**Files:**
- Modify: `BrowserRouter/BrowserRouter/MenuBarController.swift`

**Step 1: Add settingsWindow property**

After `private var popover: NSPopover?` add:

```swift
private var settingsWindow: NSWindow?
```

**Step 2: Add openSettingsWindow method**

After `togglePopover()` method, add:

```swift
func openSettingsWindow() {
    // Close popover first
    popover?.performClose(nil)

    // If window exists, just bring to front
    if let window = settingsWindow {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
    }

    // Create new settings window
    let settingsView = SettingsWindowView(settings: settings)
    let hostingController = NSHostingController(rootView: settingsView)

    let window = NSWindow(contentViewController: hostingController)
    window.title = "BrowserRouter Settings"
    window.styleMask = [.titled, .closable]
    window.center()
    window.makeKeyAndOrderFront(nil)

    NSApp.activate(ignoringOtherApps: true)

    settingsWindow = window
}
```

**Step 3: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BrowserRouter/BrowserRouter/MenuBarController.swift
git commit -m "feat: add settings window management to MenuBarController"
```

---

### Task 4: Redesign SettingsView as Compact Popover

**Files:**
- Modify: `BrowserRouter/BrowserRouter/SettingsView.swift`

**Step 1: Replace entire SettingsView with new design**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var stack: BrowserStack
    var onOpenSettings: () -> Void

    @State private var detectedBrowsers: [Browser] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)

            sectionHeader("Tracked Browsers")

            browserList
                .padding(.bottom, 12)

            Divider()
                .padding(.vertical, 8)

            bottomActions
        }
        .padding(16)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .onAppear {
            detectedBrowsers = BrowserDetector.detectBrowsers()
            if settings.fallbackBrowser == nil, let first = detectedBrowsers.first {
                settings.fallbackBrowser = first.bundleID
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BrowserRouter")
                .font(.headline)

            if let currentID = stack.mostRecent,
               let browser = detectedBrowsers.first(where: { $0.bundleID == currentID }) {
                Text("Opening links in \(browser.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No browser selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)
    }

    private var browserList: some View {
        VStack(spacing: 0) {
            ForEach(detectedBrowsers) { browser in
                browserRow(browser)
            }
        }
    }

    private func browserRow(_ browser: Browser) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: browser.icon)
                .resizable()
                .frame(width: 20, height: 20)

            Text(browser.name)
                .font(.body)

            Spacer()

            Toggle("", isOn: binding(for: browser.bundleID))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var bottomActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("BrowserRouter Settings...") {
                onOpenSettings()
            }
            .buttonStyle(.plain)

            Button("Quit BrowserRouter") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }

    private func binding(for bundleID: String) -> Binding<Bool> {
        Binding(
            get: { settings.trackedBrowsers.contains(bundleID) },
            set: { isTracked in
                if isTracked {
                    settings.trackedBrowsers.append(bundleID)
                } else {
                    settings.trackedBrowsers.removeAll { $0 == bundleID }
                }
            }
        )
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build fails - SettingsView initializer changed

**Step 3: Commit partial progress**

```bash
git add BrowserRouter/BrowserRouter/SettingsView.swift
git commit -m "feat: redesign SettingsView as compact Control Center-style popover"
```

---

### Task 5: Update App.swift for New SettingsView

**Files:**
- Modify: `BrowserRouter/BrowserRouter/App.swift`

**Step 1: Update SettingsView initialization in applicationDidFinishLaunching**

Find:
```swift
let settingsView = SettingsView(settings: settings, stack: stack)
menuBarController.setup(settingsView: settingsView)
```

Replace with:
```swift
let settingsView = SettingsView(settings: settings, stack: stack) {
    self.menuBarController.openSettingsWindow()
}
menuBarController.setup(settingsView: settingsView)
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BrowserRouter/BrowserRouter/App.swift
git commit -m "feat: wire up settings window opening from popover"
```

---

### Task 6: Update MenuBarController Popover Size

**Files:**
- Modify: `BrowserRouter/BrowserRouter/MenuBarController.swift`

**Step 1: Update popover contentSize**

Find:
```swift
popover?.contentSize = NSSize(width: 300, height: 400)
```

Replace with:
```swift
popover?.contentSize = NSSize(width: 280, height: 320)
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BrowserRouter/BrowserRouter/MenuBarController.swift
git commit -m "feat: adjust popover size for new compact design"
```

---

### Task 7: Update FirstLaunchView Styling

**Files:**
- Modify: `BrowserRouter/BrowserRouter/FirstLaunchView.swift`

**Step 1: Replace entire FirstLaunchView with styled version**

```swift
import SwiftUI
import ServiceManagement

struct FirstLaunchView: View {
    @ObservedObject var settings: AppSettings
    var onComplete: () -> Void

    @State private var detectedBrowsers: [Browser] = []
    @State private var selectedBrowsers: Set<String> = []

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Welcome to BrowserRouter")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select the browsers you want to track")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("BROWSERS")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(detectedBrowsers) { browser in
                        browserRow(browser)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button("Skip") {
                    onComplete()
                }

                Spacer()

                Button("Continue") {
                    settings.trackedBrowsers = Array(selectedBrowsers)
                    if let first = detectedBrowsers.first {
                        settings.fallbackBrowser = first.bundleID
                    }
                    promptForDefaultBrowser()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            detectedBrowsers = BrowserDetector.detectBrowsers()
            let common: Set<String> = ["com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser"]
            selectedBrowsers = common.intersection(Set(detectedBrowsers.map(\.bundleID)))
        }
    }

    private func browserRow(_ browser: Browser) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: browser.icon)
                .resizable()
                .frame(width: 20, height: 20)

            Text(browser.name)
                .font(.body)

            Spacer()

            Toggle("", isOn: Binding(
                get: { selectedBrowsers.contains(browser.bundleID) },
                set: { selected in
                    if selected {
                        selectedBrowsers.insert(browser.bundleID)
                    } else {
                        selectedBrowsers.remove(browser.bundleID)
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private func promptForDefaultBrowser() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID as CFString)
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BrowserRouter/BrowserRouter/FirstLaunchView.swift
git commit -m "feat: apply Control Center styling to FirstLaunchView"
```

---

### Task 8: Build and Install App Bundle

**Step 1: Run bundle script**

Run: `./scripts/bundle.sh`
Expected: App built and installed to ~/Applications

**Step 2: Verify installation**

Run: `ls -la ~/Applications/BrowserRouter.app/Contents/MacOS/`
Expected: BrowserRouter executable exists

**Step 3: Commit all changes**

```bash
git status
git add -A
git commit -m "feat: complete Apple-style design refresh"
```

---

### Task 9: Push to Remote

**Step 1: Push changes**

Run: `git push`
Expected: Changes pushed to origin/main

---

## Verification Checklist

After all tasks complete:
- [ ] Popover has vibrancy background
- [ ] Browser rows show actual app icons
- [ ] "BrowserRouter Settings..." opens separate window
- [ ] Settings window has grouped form style
- [ ] First launch window matches new styling
- [ ] App builds and installs successfully
