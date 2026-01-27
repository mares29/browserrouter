# Privacy

BrowserRouter is designed with privacy as a core principle. This document explains exactly what data the app accesses and stores.

## What BrowserRouter Stores

**Browser order list** - A list of browser bundle identifiers in the order you last used them, stored locally in UserDefaults.

That's it.

## What BrowserRouter Does NOT Do

- No analytics or telemetry
- No network requests of any kind
- No URL logging or history
- No data leaves your Mac
- No third-party services
- No crash reporting

## Where Data Is Stored

All data is stored locally in:

```
~/Library/Preferences/com.browserrouter.app.plist
```

This file contains:
- `trackedBrowsers` - Which browsers to monitor
- `browserStack` - Recent browser order (max 10 entries)
- `fallbackBrowser` - Your configured fallback
- `menuBarDisplayMode` - Display preference

## How to Verify

The source code is fully available. Key files to review:

- [`Sources/BrowserRouter/Settings.swift`](Sources/BrowserRouter/Settings.swift) - All UserDefaults access
- [`Sources/BrowserRouter/BrowserStack.swift`](Sources/BrowserRouter/BrowserStack.swift) - Browser order storage
- [`Sources/BrowserRouter/URLHandler.swift`](Sources/BrowserRouter/URLHandler.swift) - URL routing logic (no logging)

Search the codebase for `URL`, `network`, `http`, or `analytics` to confirm there are no hidden calls.

## How to Delete Your Data

Either:
1. Delete `~/Library/Preferences/com.browserrouter.app.plist`
2. Or simply uninstall the app - macOS removes preferences on app deletion

## Questions

If you have privacy concerns, open an issue or email mares.dev@icloud.com.
