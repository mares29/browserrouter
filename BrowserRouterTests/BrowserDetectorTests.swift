import XCTest
import AppKit
@testable import BrowserRouter

final class BrowserDetectorTests: XCTestCase {
    func test_detectBrowsers_findsSafari() {
        let browsers = BrowserDetector.detectBrowsers()

        // Safari should always be present on macOS
        let safari = browsers.first { $0.bundleID == "com.apple.Safari" }
        XCTAssertNotNil(safari)
        XCTAssertEqual(safari?.name, "Safari")
    }

    func test_detectBrowsers_returnsNonEmpty() {
        let browsers = BrowserDetector.detectBrowsers()
        XCTAssertFalse(browsers.isEmpty, "Should detect at least Safari")
    }

    func test_detectBrowsers_listsEachAppOnce() {
        let ids = BrowserDetector.detectBrowsers().map(\.bundleID)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_browserWithBundleID_resolvesInstalledApp() {
        XCTAssertEqual(BrowserDetector.browser(withBundleID: "com.apple.Safari")?.name, "Safari")
        XCTAssertNil(BrowserDetector.browser(withBundleID: "com.example.not-installed"))
    }

    func test_isBrowser_keepsHTMLHandlers() {
        XCTAssertTrue(BrowserDetector.isBrowser("com.example.browser", htmlHandlerIDs: ["com.example.browser"]))
    }

    func test_isBrowser_dropsLinkOnlyApps() {
        XCTAssertFalse(BrowserDetector.isBrowser("com.example.chat", htmlHandlerIDs: ["com.example.browser"]))
    }

    func test_isBrowser_keepsCommonBrowsersWithoutHTML() {
        for id in BrowserDetector.commonBrowserIDs {
            XCTAssertTrue(BrowserDetector.isBrowser(id, htmlHandlerIDs: []))
        }
    }

    func test_displayName_prefersDisplayName() {
        let info = ["CFBundleName": "Chrome", "CFBundleDisplayName": "Google Chrome"]
        XCTAssertEqual(BrowserDetector.displayName(info), "Google Chrome")
    }

    func test_displayName_fallsBackToBundleName() {
        XCTAssertEqual(BrowserDetector.displayName(["CFBundleName": "Nightly"]), "Nightly")
        XCTAssertNil(BrowserDetector.displayName([:]))
    }

    func test_browser_equatable() {
        let a = Browser(bundleID: "com.test", name: "Test", path: URL(fileURLWithPath: "/"), icon: NSImage())
        let b = Browser(bundleID: "com.test", name: "Test", path: URL(fileURLWithPath: "/"), icon: NSImage())
        XCTAssertEqual(a, b)
    }
}
