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
            settings.hasLaunchedBefore = true
            showFirstLaunchWindow()
        } else if settings.trackedBrowsers.isEmpty {
            // Pre-select common browsers if none selected
            let detected = Set(detectedBrowsers.map(\.bundleID))
            settings.trackedBrowsers = BrowserDetector.commonBrowserIDs.filter { detected.contains($0) }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urlHandler.handle(urls)
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusMonitor.stop()
    }

    private func showFirstLaunchWindow() {
        let firstLaunchView = FirstLaunchView(settings: settings, browsers: detectedBrowsers) { [weak self] in
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
