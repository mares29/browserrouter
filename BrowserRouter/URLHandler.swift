import Foundation
import AppKit
import os

final class URLHandler {
    private static let logger = Logger(subsystem: "com.browserrouter.app", category: "URLHandler")

    private let settings: AppSettings
    private let stack: BrowserStack

    init(settings: AppSettings, stack: BrowserStack) {
        self.settings = settings
        self.stack = stack
    }

    func handle(_ urls: [URL]) {
        guard let browser = targetBrowser() else {
            Self.logger.error("No browser available to open \(urls.count) link(s)")
            return
        }
        openURLs(urls, inBrowser: browser)
    }

    /// The browser links open in right now: the first candidate that is installed
    func targetBrowser() -> String? {
        let runningBrowsers = NSWorkspace.shared.runningApplications
            .compactMap { $0.bundleIdentifier }

        let candidates = Self.candidateBrowsers(
            fromStack: stack.browsers,
            tracked: settings.trackedBrowsers,
            running: runningBrowsers,
            fallback: settings.fallbackBrowser,
            selfID: Bundle.main.bundleIdentifier
        )
        return candidates.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    /// Browsers to try in order: running tracked browsers, most recently focused first,
    /// then the fallback, then the common browsers as a safety net.
    /// Never ourselves: we are the default browser, so that would loop.
    static func candidateBrowsers(fromStack stack: [String], tracked: [String], running: [String], fallback: String?, selfID: String?) -> [String] {
        // The stack can still hold browsers the user has since untracked
        let active = Set(tracked).intersection(running)
        let ordered = stack.filter { active.contains($0) } + [fallback].compactMap { $0 } + BrowserDetector.commonBrowserIDs

        var seen = Set<String>()
        return ordered.filter { $0 != selfID && seen.insert($0).inserted }
    }

    /// Where links go when no tracked browser is running: the browser that opened links
    /// before BrowserRouter took over, else the first selected browser, else the first installed common browser.
    /// `installed` must not contain BrowserRouter itself.
    static func defaultFallback(previousDefault: String?, selected: [String], installed: [String]) -> String? {
        if let previousDefault, installed.contains(previousDefault) {
            return previousDefault
        }
        return selected.first ?? BrowserDetector.commonBrowserIDs.first { installed.contains($0) }
    }

    private func openURLs(_ urls: [URL], inBrowser bundleID: String) {
        let config = NSWorkspace.OpenConfiguration()

        guard let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            Self.logger.error("Could not find browser \(bundleID, privacy: .public)")
            return
        }

        NSWorkspace.shared.open(urls, withApplicationAt: browserURL, configuration: config) { _, error in
            if let error {
                Self.logger.error("Failed to open URL in \(bundleID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
