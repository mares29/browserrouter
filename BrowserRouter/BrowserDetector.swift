import Foundation
import AppKit

struct Browser: Identifiable, Equatable, Hashable {
    let bundleID: String
    let name: String
    let path: URL

    var id: String { bundleID }
}

enum BrowserDetector {
    static func detectBrowsers() -> [Browser] {
        let testURL = URL(string: "https://example.com")!

        guard let appURLs = LSCopyApplicationURLsForURL(testURL as CFURL, .all)?.takeRetainedValue() as? [URL] else {
            return []
        }

        var browsers: [Browser] = []

        for appURL in appURLs {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
            else { continue }

            // Skip ourselves
            if bundleID == Bundle.main.bundleIdentifier { continue }

            browsers.append(Browser(bundleID: bundleID, name: name, path: appURL))
        }

        return browsers.sorted { $0.name < $1.name }
    }
}
