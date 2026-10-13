import Foundation
import AppKit

final class URLHandler {
    private let settings: AppSettings
    private let stack: BrowserStack

    init(settings: AppSettings, stack: BrowserStack) {
        self.settings = settings
        self.stack = stack
    }

    func handle(_ urls: [URL]) {
        // If no fallback set, URL is not opened (avoids infinite loop since we ARE the default browser)
        guard let browser = targetBrowser() else { return }
        openURLs(urls, inBrowser: browser)
    }

    /// The browser links open in right now: the most recently focused tracked browser
    /// that is still running, otherwise the fallback browser.
    func targetBrowser() -> String? {
        let runningBrowsers = NSWorkspace.shared.runningApplications
            .compactMap { $0.bundleIdentifier }

        return Self.selectBrowser(fromStack: stack.browsers, tracked: settings.trackedBrowsers, running: runningBrowsers)
            ?? settings.fallbackBrowser
    }

    static func selectBrowser(fromStack stack: [String], tracked: [String], running: [String]) -> String? {
        // The stack can still hold browsers the user has since untracked
        let candidates = Set(tracked).intersection(running)
        return stack.first { candidates.contains($0) }
    }

    private func openURLs(_ urls: [URL], inBrowser bundleID: String) {
        let config = NSWorkspace.OpenConfiguration()

        guard let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            print("BrowserRouter: Could not find browser \(bundleID)")
            return
        }

        NSWorkspace.shared.open(urls, withApplicationAt: browserURL, configuration: config) { _, error in
            if let error {
                print("BrowserRouter: Failed to open URL: \(error)")
            }
        }
    }
}
