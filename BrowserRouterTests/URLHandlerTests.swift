import XCTest
@testable import BrowserRouter

final class URLHandlerTests: XCTestCase {
    func test_selectBrowser_returnsMostRecentRunning() {
        // This is an integration test - needs running browsers
        // Unit test the selection logic instead

        let running = ["com.apple.Safari"]
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let selected = URLHandler.selectBrowser(fromStack: stack, running: running)
        XCTAssertEqual(selected, "com.apple.Safari")
    }

    func test_selectBrowser_returnsNilIfNoneRunning() {
        let running: [String] = []
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let selected = URLHandler.selectBrowser(fromStack: stack, running: running)
        XCTAssertNil(selected)
    }

    func test_selectBrowser_respectsStackOrder() {
        let running = ["com.apple.Safari", "com.google.Chrome"]
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let selected = URLHandler.selectBrowser(fromStack: stack, running: running)
        XCTAssertEqual(selected, "com.google.Chrome")
    }
}
