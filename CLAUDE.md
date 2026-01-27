# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

BrowserRouter is a macOS menu bar app that opens links in the most recently focused browser. It acts as the system default browser and forwards URLs to whichever browser (Chrome, Safari, Arc, Firefox, etc.) the user was last using.

## Build Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Build and install as .app bundle to ~/Applications
./scripts/bundle.sh

# Run tests (requires Xcode - won't work with Command Line Tools only)
swift test
```

## Architecture

The app has two core flows:

**Focus Tracking (always running):**
- `FocusMonitor` subscribes to `NSWorkspace.didActivateApplicationNotification`
- When a tracked browser gains focus, it's pushed to `BrowserStack`
- `BrowserStack` maintains an ordered list (most recent first, max 10, persisted to UserDefaults)

**URL Handling (triggered on link click):**
- macOS calls `application(_:open:)` because app registers `http`/`https` schemes in Info.plist
- `URLHandler` reads `BrowserStack`, filters to running browsers, opens URL in first match
- Falls back to explicit fallback browser, then system default

**Key Components:**
- `AppDelegate` (App.swift) - Wires everything together, handles URL open events
- `AppSettings` (Settings.swift) - UserDefaults wrapper for `trackedBrowsers`, `fallbackBrowser`, `menuBarDisplayMode`
- `BrowserDetector` - Scans installed browsers using `LSCopyApplicationURLsForURL`
- `MenuBarController` - NSStatusItem with native NSMenu (built dynamically via `NSMenuDelegate`)

## Important Notes

- The class is named `AppSettings` (not `Settings`) to avoid conflict with SwiftUI's `Settings` scene
- `LSUIElement=true` in Info.plist makes this a menu-bar-only app (no Dock icon)
- Must be packaged as `.app` bundle to register as default browser - use `scripts/bundle.sh`
