import XCTest
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

    func test_browser_equatable() {
        let a = Browser(bundleID: "com.test", name: "Test", path: URL(fileURLWithPath: "/"))
        let b = Browser(bundleID: "com.test", name: "Test", path: URL(fileURLWithPath: "/"))
        XCTAssertEqual(a, b)
    }
}
