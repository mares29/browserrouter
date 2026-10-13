import Foundation
import AppKit

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

        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probeURL) {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
            else { continue }

            // Skip ourselves
            if bundleID == Bundle.main.bundleIdentifier { continue }

            // The same app can be installed in several places; list it once
            guard seen.insert(bundleID).inserted else { continue }

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            browsers.append(Browser(bundleID: bundleID, name: name, path: appURL, icon: icon))
        }

        return browsers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
