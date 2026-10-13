# Privacy

BrowserRouter is designed with privacy as a core principle. This document explains exactly what data the app accesses and stores.

## What BrowserRouter Stores

**Browser order list** - A list of browser bundle identifiers in the order you last used them, stored locally in UserDefaults.

**Link rules** - The patterns and browsers you add under Rules, stored locally in UserDefaults.

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

The Mac App Store version is sandboxed, so it keeps the same file in its container:

```
~/Library/Containers/com.browserrouter.app/Data/Library/Preferences/com.browserrouter.app.plist
```

This file contains:
- `trackedBrowsers` - Which browsers to monitor
- `browserStack` - Recent browser order (max 10 entries)
- `fallbackBrowser` - Your configured fallback
- `menuBarDisplayMode` - Display preference
- `rules` - Your link rules (patterns and the browser each one opens)

## How to Verify

The source code is fully available. Key files to review:

- [`BrowserRouter/Settings.swift`](BrowserRouter/Settings.swift) - All UserDefaults access
- [`BrowserRouter/BrowserStack.swift`](BrowserRouter/BrowserStack.swift) - Browser order storage
- [`BrowserRouter/URLHandler.swift`](BrowserRouter/URLHandler.swift) - URL routing logic (no URL logging)

Search the codebase for `URL`, `network`, `http`, or `analytics` to confirm there are no hidden calls.

## How to Delete Your Data

Quit BrowserRouter, then delete the file listed under [Where Data Is Stored](#where-data-is-stored) for your version. Deleting the app alone does not remove it.

## Questions

If you have privacy concerns, open an issue or email mares.dev@icloud.com.
