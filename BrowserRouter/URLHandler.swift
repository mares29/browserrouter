import Foundation
import AppKit

final class URLHandler {
    private let settings: AppSettings
    private let stack: BrowserStack

    init(settings: AppSettings, stack: BrowserStack) {
        self.settings = settings
        self.stack = stack
    }

    func handle(_ url: URL) {
        let runningBrowsers = NSWorkspace.shared.runningApplications
            .compactMap { $0.bundleIdentifier }

        if let browser = Self.selectBrowser(fromStack: stack.browsers, running: runningBrowsers) {
            openURL(url, inBrowser: browser)
        } else if let fallback = settings.fallbackBrowser {
            openURL(url, inBrowser: fallback)
        }
        // If no fallback set, URL is not opened (avoids infinite loop since we ARE the default browser)
    }

    static func selectBrowser(fromStack stack: [String], running: [String]) -> String? {
        let runningSet = Set(running)
        return stack.first { runningSet.contains($0) }
    }

    private func openURL(_ url: URL, inBrowser bundleID: String) {
        let config = NSWorkspace.OpenConfiguration()

        guard let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            print("BrowserRouter: Could not find browser \(bundleID)")
            return
        }

        NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: config) { _, error in
            if let error {
                print("BrowserRouter: Failed to open URL: \(error)")
            }
        }
    }
}
