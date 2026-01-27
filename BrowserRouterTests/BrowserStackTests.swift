import XCTest
@testable import BrowserRouter

final class BrowserStackTests: XCTestCase {
    var stack: BrowserStack!
    var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "test-stack")!
        defaults.removePersistentDomain(forName: "test-stack")
        stack = BrowserStack(defaults: defaults)
    }

    func test_empty_initially() {
        XCTAssertEqual(stack.browsers, [])
    }

    func test_recordFocus_addsBrowserToFront() {
        stack.recordFocus("com.apple.Safari")
        XCTAssertEqual(stack.browsers, ["com.apple.Safari"])

        stack.recordFocus("com.google.Chrome")
        XCTAssertEqual(stack.browsers, ["com.google.Chrome", "com.apple.Safari"])
    }

    func test_recordFocus_deduplicates() {
        stack.recordFocus("com.apple.Safari")
        stack.recordFocus("com.google.Chrome")
        stack.recordFocus("com.apple.Safari")

        XCTAssertEqual(stack.browsers, ["com.apple.Safari", "com.google.Chrome"])
    }

    func test_recordFocus_limitsToTen() {
        for i in 0..<15 {
            stack.recordFocus("browser.\(i)")
        }

        XCTAssertEqual(stack.browsers.count, 10)
        XCTAssertEqual(stack.browsers.first, "browser.14")
    }

    func test_persists_acrossInstances() {
        stack.recordFocus("com.apple.Safari")

        let reloaded = BrowserStack(defaults: defaults)
        XCTAssertEqual(reloaded.browsers, ["com.apple.Safari"])
    }

    func test_mostRecent_returnsFirst() {
        stack.recordFocus("com.apple.Safari")
        stack.recordFocus("com.google.Chrome")

        XCTAssertEqual(stack.mostRecent, "com.google.Chrome")
    }

    func test_mostRecent_nilWhenEmpty() {
        XCTAssertNil(stack.mostRecent)
    }
}
