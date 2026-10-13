import SwiftUI
import AppKit

@main
struct BrowserRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings!
    private var stack: BrowserStack!
    private var focusMonitor: FocusMonitor!
    private var urlHandler: URLHandler!
    private var menuBarController: MenuBarController!
    private var firstLaunchWindow: NSWindow?
    private var detectedBrowsers: [Browser] = []
    /// Links that arrive before setup finishes
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = AppSettings()
        stack = BrowserStack()
        detectedBrowsers = BrowserDetector.detectBrowsers()

        focusMonitor = FocusMonitor(settings: settings, stack: stack)
        urlHandler = URLHandler(settings: settings, stack: stack)
        menuBarController = MenuBarController(settings: settings, stack: stack, urlHandler: urlHandler, browsers: detectedBrowsers) { [weak self] in
            self?.showFirstLaunchWindow()
        }

        menuBarController.setup()

        focusMonitor.start()

        // Check if first launch
        if !settings.hasLaunchedBefore {
            // Seed defaults so Skip or closing the welcome window still leaves a working setup.
            // Read the previous default before the welcome screen makes us the default.
            let previousDefault = BrowserDetector.systemDefaultBrowserID()
            let installed = detectedBrowsers.map(\.bundleID)
            settings.trackedBrowsers = BrowserDetector.commonBrowserIDs.filter { installed.contains($0) }
            settings.fallbackBrowser = URLHandler.defaultFallback(previousDefault: previousDefault, selected: settings.trackedBrowsers, installed: installed)
            settings.hasLaunchedBefore = true

            showFirstLaunchWindow()
        }

        // The link that launched us, now that the settings are seeded
        if !pendingURLs.isEmpty {
            urlHandler.handle(pendingURLs)
            pendingURLs = []
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // A link that launches the app arrives before applicationDidFinishLaunching
        guard let urlHandler else {
            pendingURLs += urls
            return
        }
        urlHandler.handle(urls)
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusMonitor.stop()
    }

    /// The welcome window, on first launch or from Show Welcome… in the menu
    private func showFirstLaunchWindow() {
        if let window = firstLaunchWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Scan again, so browsers installed since launch show up when it's opened from the menu
        detectedBrowsers = BrowserDetector.detectBrowsers()

        let firstLaunchView = FirstLaunchView(settings: settings, browsers: detectedBrowsers) { [weak self] in
            self?.firstLaunchWindow?.close()
            self?.firstLaunchWindow = nil
        }

        let hostingController = NSHostingController(rootView: firstLaunchView)

        let window = NSWindow(contentViewController: hostingController)
        // We keep our own reference, so closing must not release it as well
        window.isReleasedWhenClosed = false
        window.title = "Welcome to BrowserRouter"
        // Each step has its own heading, so the title bar stays out of the way
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Activate the app to bring window to front
        NSApp.activate(ignoringOtherApps: true)

        firstLaunchWindow = window
    }
}
