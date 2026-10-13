import Foundation
import AppKit
import os
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
    private static let logger = Logger(subsystem: "com.browserrouter.app", category: "BrowserDetector")

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

    /// An installed app as a Browser, whether or not detection lists it
    static func browser(withBundleID bundleID: String) -> Browser? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let name = Bundle(url: appURL).flatMap({ displayName($0.infoDictionary ?? [:]) })
        else { return nil }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        return Browser(bundleID: bundleID, name: name, path: appURL, icon: icon)
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
        handlerID(forScheme: "https")
    }

    /// Name of the app macOS currently opens web links with
    static func systemDefaultBrowserName() -> String? {
        systemDefaultBrowserID().flatMap(browser(withBundleID:))?.name
    }

    /// Whether macOS sends both http and https links to BrowserRouter
    static func isSelfDefault() -> Bool {
        guard let selfID = Bundle.main.bundleIdentifier else { return false }
        return webSchemes.allSatisfy { handlerID(forScheme: $0) == selfID }
    }

    /// Registers BrowserRouter for http/https. macOS asks the user to confirm,
    /// then `completion` gets whether BrowserRouter is now the default.
    static func setSelfAsDefault(completion: @escaping (Bool) -> Void = { _ in }) {
        setSelfAsDefault(for: webSchemes[...], completion: completion)
    }

    private static func setSelfAsDefault(for schemes: ArraySlice<String>, completion: @escaping (Bool) -> Void) {
        // Every scheme was already ours or macOS accepted it. Don't look it up again:
        // LaunchServices can take a moment to report the change.
        guard let scheme = schemes.first else {
            completion(true)
            return
        }
        let rest = schemes.dropFirst()

        // Accepting the prompt for one scheme can cover both, so skip one that is already ours
        guard handlerID(forScheme: scheme) != Bundle.main.bundleIdentifier else {
            setSelfAsDefault(for: rest, completion: completion)
            return
        }

        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme) { error in
            DispatchQueue.main.async {
                if let error {
                    // Also what declining the prompt looks like
                    logger.error("Could not become the default for \(scheme, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    completion(isSelfDefault())
                } else {
                    setSelfAsDefault(for: rest, completion: completion)
                }
            }
        }
    }

    /// System Settings › Desktop & Dock, where the default web browser is chosen
    static func openDefaultBrowserSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private static let webSchemes = ["http", "https"]

    private static func handlerID(forScheme scheme: String) -> String? {
        guard let url = URL(string: "\(scheme)://example.com"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: url)
        else { return nil }
        // The sandbox can't read every app's bundle, but it can always read its own
        if appURL.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL {
            return Bundle.main.bundleIdentifier
        }
        return Bundle(url: appURL)?.bundleIdentifier
    }
}
