# BrowserRouter

A macOS menu bar app that opens links in the most recently focused browser.

Fully open source — verify the code yourself. Built with [Claude Code](https://claude.ai/code).

## Why?

When using multiple browsers (Chrome, Safari, Arc, Firefox), clicking links in other apps always opens in a fixed default browser. BrowserRouter fixes this by tracking which browser you were last using and routing links there.

## Installation

### Download

Download the latest release from [GitHub Releases](https://github.com/mares29/browserrouter/releases).

1. Download `BrowserRouter-vX.X.X.zip`
2. Unzip and drag `BrowserRouter.app` to your Applications folder
3. Remove the quarantine attribute (required for unsigned apps):
   ```bash
   xattr -cr /Applications/BrowserRouter.app
   ```
4. Open the app normally

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
- Choose which browsers to track (Tracked Browsers submenu)
- Set a fallback browser (Fallback Browser submenu)
- Configure menu bar display (icon only, icon + letter, or icon + name)
- Enable launch at login
- Set BrowserRouter as default browser

## How It Works

1. Registers as a handler for `http://` and `https://` URLs
2. Listens for `NSWorkspace.didActivateApplicationNotification` to track browser focus
3. When a URL is opened, routes it to the most recently focused (and currently running) browser

## Privacy

BrowserRouter stores only a list of your recently used browsers locally on your Mac. No analytics, no network requests, no URL logging. See [PRIVACY.md](PRIVACY.md) for details.

## License

[MIT](LICENSE)
