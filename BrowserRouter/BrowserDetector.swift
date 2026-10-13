import Foundation
import AppKit
import UniformTypeIdentifiers

struct Browser: Identifiable, Equatable, Hashable {
    let bundleID: String
    let name: String
    let path: URL
    let icon: NSImage

    var id: String { bundleID }

    // Hashable conformance - exclude icon from hash
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }

    static func == (lhs: Browser, rhs: Browser) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}

enum BrowserDetector {
    /// Browsers tracked by default when the user hasn't picked any
    static let commonBrowserIDs = ["com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser", "org.mozilla.firefox"]

    private static let probeURL = URL(string: "https://example.com")!

    static func detectBrowsers() -> [Browser] {
        var browsers: [Browser] = []
        var seen = Set<String>()

        // Compare bundle IDs, not paths: the same app can be registered from several locations
        let htmlHandlerIDs = Set(NSWorkspace.shared.urlsForApplications(toOpen: UTType.html)
            .compactMap { Bundle(url: $0)?.bundleIdentifier })

        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probeURL) {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  let name = displayName(bundle.infoDictionary ?? [:])
            else { continue }

            // Skip ourselves
            if bundleID == Bundle.main.bundleIdentifier { continue }

            guard isBrowser(bundleID, htmlHandlerIDs: htmlHandlerIDs) else { continue }

            // The same app can be installed in several places; list it once
            guard seen.insert(bundleID).inserted else { continue }

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            browsers.append(Browser(bundleID: bundleID, name: name, path: appURL, icon: icon))
        }

        return browsers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Real browsers also open HTML files; apps that only claim web links (chat clients, terminals) don't.
    /// Common browsers are always kept in case their HTML registration is missing.
    static func isBrowser(_ bundleID: String, htmlHandlerIDs: Set<String>) -> Bool {
        htmlHandlerIDs.contains(bundleID) || commonBrowserIDs.contains(bundleID)
    }

    /// "Google Chrome" rather than its short bundle name "Chrome"
    static func displayName(_ info: [String: Any]) -> String? {
        info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String
    }

    /// Bundle ID of the app macOS currently opens web links with
    static func systemDefaultBrowserID() -> String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: probeURL) else { return nil }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    /// Registers BrowserRouter for http/https. macOS asks the user to confirm.
    static func setSelfAsDefault() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID as CFString)
    }
}
