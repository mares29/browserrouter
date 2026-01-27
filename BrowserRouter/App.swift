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

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = AppSettings()
        stack = BrowserStack()
        focusMonitor = FocusMonitor(settings: settings, stack: stack)
        urlHandler = URLHandler(settings: settings, stack: stack)
        menuBarController = MenuBarController()

        let settingsView = SettingsView(settings: settings, stack: stack)
        menuBarController.setup(settingsView: settingsView)

        focusMonitor.start()

        // Check if first launch
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            showFirstLaunchWindow()
        } else if settings.trackedBrowsers.isEmpty {
            // Pre-select common browsers if none selected
            let common = ["com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser", "org.mozilla.firefox"]
            let detected = Set(BrowserDetector.detectBrowsers().map(\.bundleID))
            settings.trackedBrowsers = common.filter { detected.contains($0) }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            urlHandler.handle(url)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusMonitor.stop()
    }

    private func showFirstLaunchWindow() {
        let firstLaunchView = FirstLaunchView(settings: settings) { [weak self] in
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
