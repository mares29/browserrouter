# BrowserRouter

A macOS menu bar app that opens links in the most recently focused browser.

## Why?

When using multiple browsers (Chrome, Safari, Arc, Firefox), clicking links in other apps always opens in a fixed default browser. BrowserRouter fixes this by tracking which browser you were last using and routing links there.

## Installation

### Build from source

Requires Swift 5.9+ and macOS 13+.

```bash
git clone https://github.com/mares29/browserrouter.git
cd browserrouter
./scripts/bundle.sh
```

This builds the app and installs it to `~/Applications`.

### First launch

1. Open `~/Applications/BrowserRouter.app`
2. A globe icon appears in the menu bar
3. Go to **System Settings → Desktop & Dock → Default web browser**
4. Select **BrowserRouter**

## Usage

Just use your Mac normally. BrowserRouter runs in the background and:

- Tracks which browser you switch to
- When you click a link (in Mail, Slack, etc.), it opens in your last-used browser
- If that browser isn't running, it tries the next most recent one
- Falls back to your configured fallback browser or system default

Click the menu bar icon to:
- See which browser is currently active
- Choose which browsers to track
- Set a fallback browser
- Enable launch at login

## How It Works

1. Registers as a handler for `http://` and `https://` URLs
2. Listens for `NSWorkspace.didActivateApplicationNotification` to track browser focus
3. When a URL is opened, routes it to the most recently focused (and currently running) browser

## License

MIT
