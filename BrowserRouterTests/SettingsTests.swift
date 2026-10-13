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

    func test_rules_defaultToEmpty() {
        XCTAssertEqual(settings.rules, [])
    }

    func test_rules_persistInOrder() {
        settings.rules = [
            URLRule(kind: .domain, pattern: "github.com", browserID: "com.google.Chrome"),
            URLRule(kind: .contains, pattern: "meet", browserID: "com.apple.Safari", isEnabled: false),
        ]

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.rules, settings.rules)
    }

    func test_rules_persistEdits() {
        settings.rules = [URLRule(kind: .domain, pattern: "github.com", browserID: "com.google.Chrome")]
        settings.rules[0].isEnabled = false

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.rules.first?.isEnabled, false)
    }

    func test_rules_emptyIfStoredDataIsUnreadable() {
        defaults.set(Data("not json".utf8), forKey: "rules")

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.rules, [])
    }

    func test_hasLaunchedBefore_defaultsToFalse() {
        XCTAssertFalse(settings.hasLaunchedBefore)
    }

    func test_hasLaunchedBefore_persistsChanges() {
        settings.hasLaunchedBefore = true

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertTrue(reloaded.hasLaunchedBefore)
    }
}
