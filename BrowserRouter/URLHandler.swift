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
        } else {
            openURLWithSystemDefault(url)
        }
    }

    static func selectBrowser(fromStack stack: [String], running: [String]) -> String? {
        let runningSet = Set(running)
        return stack.first { runningSet.contains($0) }
    }

    private func openURL(_ url: URL, inBrowser bundleID: String) {
        let config = NSWorkspace.OpenConfiguration()

        guard let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            openURLWithSystemDefault(url)
            return
        }

        NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: config) { _, error in
            if error != nil {
                self.openURLWithSystemDefault(url)
            }
        }
    }

    private func openURLWithSystemDefault(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
