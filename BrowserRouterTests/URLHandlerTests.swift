import XCTest
@testable import BrowserRouter

final class URLHandlerTests: XCTestCase {
    private let tracked = ["com.apple.Safari", "com.google.Chrome"]

    func test_selectBrowser_returnsMostRecentRunning() {
        // This is an integration test - needs running browsers
        // Unit test the selection logic instead

        let running = ["com.apple.Safari"]
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let selected = URLHandler.selectBrowser(fromStack: stack, tracked: tracked, running: running)
        XCTAssertEqual(selected, "com.apple.Safari")
    }

    func test_selectBrowser_returnsNilIfNoneRunning() {
        let running: [String] = []
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let selected = URLHandler.selectBrowser(fromStack: stack, tracked: tracked, running: running)
        XCTAssertNil(selected)
    }

    func test_selectBrowser_respectsStackOrder() {
        let running = ["com.apple.Safari", "com.google.Chrome"]
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let selected = URLHandler.selectBrowser(fromStack: stack, tracked: tracked, running: running)
        XCTAssertEqual(selected, "com.google.Chrome")
    }

    func test_selectBrowser_skipsUntrackedBrowsers() {
        let running = ["org.mozilla.firefox", "com.apple.Safari"]
        let stack = ["org.mozilla.firefox", "com.apple.Safari"]

        let selected = URLHandler.selectBrowser(fromStack: stack, tracked: tracked, running: running)
        XCTAssertEqual(selected, "com.apple.Safari")
    }

    func test_selectBrowser_returnsNilIfNothingTracked() {
        let running = ["com.apple.Safari"]
        let stack = ["com.apple.Safari"]

        let selected = URLHandler.selectBrowser(fromStack: stack, tracked: [], running: running)
        XCTAssertNil(selected)
    }
}
