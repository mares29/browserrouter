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

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = AppSettings()
        stack = BrowserStack()
        detectedBrowsers = BrowserDetector.detectBrowsers()

        focusMonitor = FocusMonitor(settings: settings, stack: stack)
        urlHandler = URLHandler(settings: settings, stack: stack)
        menuBarController = MenuBarController(settings: settings, stack: stack, urlHandler: urlHandler, browsers: detectedBrowsers)

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

            showFirstLaunchWindow(previousDefault: previousDefault)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urlHandler.handle(urls)
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusMonitor.stop()
    }

    private func showFirstLaunchWindow(previousDefault: String?) {
        let firstLaunchView = FirstLaunchView(settings: settings, browsers: detectedBrowsers, previousDefault: previousDefault) { [weak self] in
            self?.firstLaunchWindow?.close()
            self?.firstLaunchWindow = nil
        }

        let hostingController = NSHostingController(rootView: firstLaunchView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to BrowserRouter"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Activate the app to bring window to front
        NSApp.activate(ignoringOtherApps: true)

        firstLaunchWindow = window
    }
}
