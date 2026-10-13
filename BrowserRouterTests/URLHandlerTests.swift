import XCTest
@testable import BrowserRouter

final class URLHandlerTests: XCTestCase {
    private let tracked = ["com.apple.Safari", "com.google.Chrome"]
    private let selfID = "com.browserrouter.app"
    private let safetyNet = BrowserDetector.commonBrowserIDs

    // Selection logic is unit tested here; opening needs real running browsers

    func test_candidates_startWithMostRecentRunning() {
        let running = ["com.apple.Safari"]
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: tracked, running: running, fallback: nil, selfID: selfID)
        XCTAssertEqual(candidates.first, "com.apple.Safari")
    }

    func test_candidates_onlySafetyNetIfNoneRunning() {
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: tracked, running: [], fallback: nil, selfID: selfID)
        XCTAssertEqual(candidates, safetyNet)
    }

    func test_candidates_respectStackOrder() {
        let running = ["com.apple.Safari", "com.google.Chrome"]
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: tracked, running: running, fallback: nil, selfID: selfID)
        XCTAssertEqual(Array(candidates.prefix(2)), ["com.google.Chrome", "com.apple.Safari"])
    }

    func test_candidates_skipUntrackedBrowsers() {
        let running = ["com.brave.Browser", "com.apple.Safari"]
        let stack = ["com.brave.Browser", "com.apple.Safari"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: tracked, running: running, fallback: nil, selfID: selfID)
        XCTAssertEqual(candidates.first, "com.apple.Safari")
        XCTAssertFalse(candidates.contains("com.brave.Browser"))
    }

    func test_candidates_skipStackIfNothingTracked() {
        let running = ["com.brave.Browser"]
        let stack = ["com.brave.Browser"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: [], running: running, fallback: nil, selfID: selfID)
        XCTAssertEqual(candidates, safetyNet)
    }

    func test_candidates_fallbackAfterRunningTracked() {
        let running = ["com.brave.Browser"]
        let stack = ["com.brave.Browser"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: ["com.brave.Browser"], running: running, fallback: "com.microsoft.edgemac", selfID: selfID)
        XCTAssertEqual(Array(candidates.prefix(2)), ["com.brave.Browser", "com.microsoft.edgemac"])
    }

    func test_candidates_safetyNetComesLast() {
        let running = ["com.brave.Browser"]
        let stack = ["com.brave.Browser"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: ["com.brave.Browser"], running: running, fallback: "com.microsoft.edgemac", selfID: selfID)
        XCTAssertEqual(candidates, ["com.brave.Browser", "com.microsoft.edgemac"] + safetyNet)
    }

    func test_candidates_excludeSelf() {
        let running = [selfID, "com.apple.Safari"]
        let stack = [selfID, "com.apple.Safari"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: [selfID, "com.apple.Safari"], running: running, fallback: selfID, selfID: selfID)
        XCTAssertFalse(candidates.contains(selfID))
        XCTAssertEqual(candidates.first, "com.apple.Safari")
    }

    func test_candidates_haveNoDuplicates() {
        let running = ["com.apple.Safari", "com.google.Chrome"]
        let stack = ["com.google.Chrome", "com.apple.Safari"]

        let candidates = URLHandler.candidateBrowsers(fromStack: stack, tracked: tracked, running: running, fallback: "com.apple.Safari", selfID: selfID)
        XCTAssertEqual(candidates.count, Set(candidates).count)
        XCTAssertEqual(Array(candidates.prefix(2)), ["com.google.Chrome", "com.apple.Safari"])
    }

    func test_defaultFallback_prefersPreviousDefault() {
        let installed = ["com.apple.Safari", "com.google.Chrome", "com.brave.Browser"]

        let fallback = URLHandler.defaultFallback(previousDefault: "com.brave.Browser", selected: ["com.google.Chrome"], installed: installed)
        XCTAssertEqual(fallback, "com.brave.Browser")
    }

    func test_defaultFallback_ignoresPreviousDefaultIfNotInstalled() {
        // e.g. BrowserRouter was already the default
        let installed = ["com.apple.Safari", "com.google.Chrome"]

        let fallback = URLHandler.defaultFallback(previousDefault: selfID, selected: ["com.google.Chrome"], installed: installed)
        XCTAssertEqual(fallback, "com.google.Chrome")
    }

    func test_defaultFallback_usesCommonBrowserIfNothingSelected() {
        let installed = ["com.brave.Browser", "com.google.Chrome"]

        let fallback = URLHandler.defaultFallback(previousDefault: nil, selected: [], installed: installed)
        XCTAssertEqual(fallback, "com.google.Chrome")
    }
}
