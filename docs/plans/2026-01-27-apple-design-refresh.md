# Apple-Style Design Refresh

## Goal

Redesign BrowserRouter UI to match macOS Control Center / System Settings visual language.

## Design Decisions

- **Popover style:** Control Center (vibrancy, section headers, compact)
- **Browser rows:** Icon + Name + Toggle (like Wi-Fi networks)
- **Current browser:** Subtle status line below title
- **Settings access:** "BrowserRouter Settings..." link opens separate window
- **Settings window:** System Settings panel style (grouped form sections)
- **Icons:** Actual app icons from bundles, not SF Symbols

---

## Popover Design

### Structure

```
┌─────────────────────────────────┐
│  BrowserRouter                  │  ← .headline
│  Opening links in Safari        │  ← .caption, .secondary
├─────────────────────────────────┤
│  TRACKED BROWSERS               │  ← .caption2, .tertiary, uppercase
│  🌐 Safari                    ⬛│  ← 20×20 icon + name + small toggle
│  🌐 Chrome                    ⬜│
│  🌐 Arc                       ⬛│
├─────────────────────────────────┤
│  BrowserRouter Settings...      │  ← plain button, primary color
│  Quit BrowserRouter             │  ← plain button, red
└─────────────────────────────────┘
```

### Specifications

- **Size:** ~280×320
- **Background:** `.ultraThinMaterial` for vibrancy
- **Padding:** 16pt standard
- **Row spacing:** 4pt vertical padding per row
- **Icon spacing:** 12pt between icon and text

### Browser Row

```swift
HStack(spacing: 12) {
    Image(nsImage: browser.icon)
        .resizable()
        .frame(width: 20, height: 20)
    Text(browser.name)
        .font(.body)
    Spacer()
    Toggle("", isOn: binding)
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
}
.padding(.vertical, 4)
```

### Section Header

```swift
Text("TRACKED BROWSERS")
    .font(.caption2)
    .foregroundStyle(.tertiary)
    .textCase(.uppercase)
    .padding(.top, 8)
```

### Status Line

```swift
Text("Opening links in \(browserName)")
    .font(.caption)
    .foregroundStyle(.secondary)
```

---

## Settings Window Design

### Window Properties

- **Size:** ~400×300
- **Title:** "BrowserRouter Settings"
- **Style:** `.titled`, `.closable` only (no minimize/zoom)
- **Content:** SwiftUI Form with `.formStyle(.grouped)`

### Structure

```
┌──────────────────────────────────────────┐
│  ● ○ ○   BrowserRouter Settings          │
├──────────────────────────────────────────┤
│                                          │
│  ┌─ General ───────────────────────────┐ │
│  │  Fallback Browser     [Safari    ▼] │ │
│  │  Menu Bar Display     [◉][S][Safari]│ │
│  │  Launch at Login          [  ⬛ ]   │ │
│  └─────────────────────────────────────┘ │
│                                          │
│  ┌─ Actions ───────────────────────────┐ │
│  │        [ Rescan Browsers ]          │ │
│  │    [ Set as Default Browser ]       │ │
│  └─────────────────────────────────────┘ │
│                                          │
└──────────────────────────────────────────┘
```

### Form Structure

```swift
Form {
    Section("General") {
        Picker("Fallback Browser", selection: $settings.fallbackBrowser) { ... }
            .pickerStyle(.menu)

        Picker("Menu Bar Display", selection: $settings.menuBarDisplayMode) { ... }
            .pickerStyle(.segmented)

        Toggle("Launch at Login", isOn: $launchAtLogin)
    }

    Section("Actions") {
        Button("Rescan Browsers") { ... }
        Button("Set as Default Browser") { ... }
    }
}
.formStyle(.grouped)
```

---

## Icon Loading

### Browser Struct Update

```swift
struct Browser: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage

    var id: String { bundleID }
}
```

### BrowserDetector Update

```swift
static func detectBrowsers() -> [Browser] {
    // ... existing detection logic ...

    let icon = NSWorkspace.shared.icon(forFile: appURL.path)
    icon.size = NSSize(width: 20, height: 20)

    return Browser(bundleID: bundleID, name: name, icon: icon)
}
```

---

## First Launch Window

Apply same styling principles:
- Vibrancy background
- Browser list with icon + name + toggle rows
- Section headers in `.caption2`, `.tertiary`
- Keep "Continue" as `.borderedProminent`

---

## Files to Modify

| File | Changes |
|------|---------|
| `BrowserDetector.swift` | Add icon loading to Browser struct |
| `SettingsView.swift` | Redesign as compact popover view |
| `SettingsWindowView.swift` | New file - full settings window |
| `MenuBarController.swift` | Add settings window management |
| `FirstLaunchView.swift` | Apply consistent styling |

---

## Implementation Notes

- Use `NSWorkspace.shared.icon(forFile:)` for app icons
- Settings window created on-demand, not at launch
- Close popover when opening settings window
- `NSApp.activate(ignoringOtherApps: true)` to bring settings window to front
