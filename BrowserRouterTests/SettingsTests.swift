import XCTest
@testable import BrowserRouter

final class AppSettingsTests: XCTestCase {
    var settings: AppSettings!
    var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "test")!
        defaults.removePersistentDomain(forName: "test")
        settings = AppSettings(defaults: defaults)
    }

    func test_trackedBrowsers_defaultsToEmpty() {
        XCTAssertEqual(settings.trackedBrowsers, [])
    }

    func test_trackedBrowsers_persistsChanges() {
        settings.trackedBrowsers = ["com.apple.Safari", "com.google.Chrome"]

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.trackedBrowsers, ["com.apple.Safari", "com.google.Chrome"])
    }

    func test_fallbackBrowser_defaultsToNil() {
        XCTAssertNil(settings.fallbackBrowser)
    }

    func test_fallbackBrowser_persistsChanges() {
        settings.fallbackBrowser = "com.apple.Safari"

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.fallbackBrowser, "com.apple.Safari")
    }
}
