# Menu Bar Display Mode

Show current browser info next to menu bar icon.

## Display Modes

1. **Icon only** - Just the globe icon (default)
2. **Icon + letter** - Globe + first letter of browser name (e.g., "🌐 S")
3. **Icon + name** - Globe + full browser name (e.g., "🌐 Safari")

When no browser has been focused yet, show icon only regardless of setting.

## Changes

### AppSettings

Add enum and property:

```swift
enum MenuBarDisplayMode: Int {
    case iconOnly = 0
    case iconAndLetter = 1
    case iconAndName = 2
}

@Published var menuBarDisplayMode: MenuBarDisplayMode
```

### MenuBarController

- Add references to `AppSettings` and list of detected browsers
- Use Combine to observe `BrowserStack.browsers` and `AppSettings.menuBarDisplayMode`
- Update `statusItem.button.title` when either changes:
  - `nil` or `.iconOnly` → empty string
  - `.iconAndLetter` → " " + first letter
  - `.iconAndName` → " " + full name

### SettingsView

Add picker after fallback browser section:

```
Menu bar display:
[Picker: Icon only | Icon + letter | Icon + name]
```

## Data Flow

```
Browser focused → BrowserStack updates → MenuBarController observes → title updates
Setting changed → AppSettings updates → MenuBarController observes → title updates
```
