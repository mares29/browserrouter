import XCTest
@testable import BrowserRouter

final class URLRuleTests: XCTestCase {
    private func rule(_ kind: URLRule.Kind, _ pattern: String) -> URLRule {
        URLRule(kind: kind, pattern: pattern, browserID: "com.google.Chrome")
    }

    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    // MARK: - Domain

    func test_domain_matchesItself() {
        XCTAssertTrue(rule(.domain, "github.com").matches(url("https://github.com/mares29/browserrouter")))
    }

    func test_domain_matchesSubdomains() {
        XCTAssertTrue(rule(.domain, "github.com").matches(url("https://gist.github.com/x")))
        XCTAssertTrue(rule(.domain, "github.com").matches(url("https://a.b.github.com")))
    }

    func test_domain_skipsLookalikes() {
        XCTAssertFalse(rule(.domain, "github.com").matches(url("https://notgithub.com")))
        XCTAssertFalse(rule(.domain, "github.com").matches(url("https://github.com.evil.example")))
        XCTAssertFalse(rule(.domain, "github.com").matches(url("https://example.com/github.com")))
    }

    func test_domain_skipsParentDomain() {
        XCTAssertFalse(rule(.domain, "gist.github.com").matches(url("https://github.com")))
    }

    func test_domain_ignoresCase() {
        XCTAssertTrue(rule(.domain, "GitHub.com").matches(url("https://GITHUB.COM/x")))
    }

    func test_domain_acceptsPastedLink() {
        XCTAssertTrue(rule(.domain, "https://www.github.com/mares29?tab=repos").matches(url("https://gist.github.com")))
    }

    func test_domain_acceptsWildcardPrefix() {
        XCTAssertTrue(rule(.domain, "*.github.com").matches(url("https://gist.github.com")))
    }

    func test_domain_wwwPatternMatchesBareDomain() {
        XCTAssertTrue(rule(.domain, "www.github.com").matches(url("https://github.com")))
    }

    func test_domain_ignoresTrailingDot() {
        XCTAssertTrue(rule(.domain, "github.com.").matches(url("https://github.com/x")))
        XCTAssertTrue(rule(.domain, "github.com").matches(url("https://github.com./x")))
    }

    func test_domain_acceptsLeadingDot() {
        XCTAssertTrue(rule(.domain, ".github.com").matches(url("https://gist.github.com")))
    }

    func test_domain_withPortMatchesOnlyThatPort() {
        let local = rule(.domain, "localhost:3000")
        XCTAssertTrue(local.matches(url("http://localhost:3000/admin")))
        XCTAssertFalse(local.matches(url("http://localhost:8080/admin")))
        XCTAssertFalse(local.matches(url("http://localhost/admin")))
    }

    func test_domain_withoutPortMatchesAnyPort() {
        XCTAssertTrue(rule(.domain, "localhost").matches(url("http://localhost:3000")))
    }

    func test_domain_defaultPortMatchesLinksWithoutPort() {
        XCTAssertTrue(rule(.domain, "github.com:443").matches(url("https://github.com/x")))
        XCTAssertTrue(rule(.domain, "localhost:80").matches(url("http://localhost/x")))
        XCTAssertFalse(rule(.domain, "github.com:443").matches(url("http://github.com/x")))
    }

    func test_domain_matchesIPv6() {
        let local = rule(.domain, "[::1]:3000")
        XCTAssertTrue(local.matches(url("http://[::1]:3000/x")))
        XCTAssertFalse(local.matches(url("http://[::1]:8080/x")))
        XCTAssertTrue(rule(.domain, "http://[::1]:3000/x").matches(url("http://[::1]:3000/")))
    }

    func test_domain_matchesInternationalDomains() {
        // macOS hands over such links in punycode; the pattern may be typed either way
        let link = url("https://www.xn--mnchen-3ya.de/")
        XCTAssertTrue(rule(.domain, "xn--mnchen-3ya.de").matches(link))
        XCTAssertTrue(rule(.domain, "münchen.de").matches(link))
    }

    func test_domain_emptyOrBlankMatchesNothing() {
        XCTAssertFalse(rule(.domain, "").matches(url("https://github.com")))
        XCTAssertFalse(rule(.domain, "   ").matches(url("https://github.com")))
    }

    func test_domain_matchesNothingWithoutHost() {
        XCTAssertFalse(rule(.domain, "github.com").matches(url("about:blank")))
    }

    // MARK: - Contains

    func test_contains_matchesAnywhere() {
        let meet = rule(.contains, "meet.google.com")
        XCTAssertTrue(meet.matches(url("https://meet.google.com/abc-defg-hij")))
        XCTAssertTrue(rule(.contains, "/pull/").matches(url("https://github.com/org/repo/pull/12")))
        XCTAssertFalse(meet.matches(url("https://calendar.google.com")))
    }

    func test_contains_ignoresCase() {
        XCTAssertTrue(rule(.contains, "JIRA").matches(url("https://company.atlassian.net/jira/browse/X-1")))
    }

    func test_contains_trimsPattern() {
        XCTAssertTrue(rule(.contains, " zoom.us\n").matches(url("https://us02web.zoom.us/j/123")))
    }

    func test_contains_matchesDecodedLink() {
        XCTAssertTrue(rule(.contains, "Q3 plan").matches(url("https://docs.example.com/Q3%20plan")))
    }

    func test_contains_emptyMatchesNothing() {
        XCTAssertFalse(rule(.contains, "").matches(url("https://github.com")))
    }

    // MARK: - Regex

    func test_regex_matches() {
        let zoom = rule(.regex, #"^https://[^/]+\.zoom\.us/j/"#)
        XCTAssertTrue(zoom.matches(url("https://us02web.zoom.us/j/123")))
        XCTAssertFalse(zoom.matches(url("https://zoom.us/pricing")))
    }

    func test_regex_ignoresCase() {
        XCTAssertTrue(rule(.regex, "youtube\\.com/watch").matches(url("https://www.YouTube.com/watch?v=1")))
    }

    func test_regex_invalidMatchesNothing() {
        XCTAssertFalse(rule(.regex, "(unclosed").matches(url("https://(unclosed")))
    }

    func test_regex_runawayGivesUpQuickly() {
        // Nested quantifiers backtrack for minutes on a long host that doesn't match
        let runaway = rule(.regex, #"^https://([a-z0-9]+\.?)+\.zoom\.us/j/"#)
        let start = Date()
        XCTAssertFalse(runaway.matches(url("https://confluence.mycompany.com/display/x")))
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertTrue(runaway.matches(url("https://us02web.zoom.us/j/123")))
    }

    // MARK: - Validation and saving

    func test_isValid_rejectsEmptyPatterns() {
        for kind in URLRule.Kind.allCases {
            XCTAssertFalse(URLRule.isValid("  ", kind: kind), "\(kind)")
        }
    }

    func test_isValid_checksRegex() {
        XCTAssertTrue(URLRule.isValid("zoom\\.us", kind: .regex))
        XCTAssertFalse(URLRule.isValid("(unclosed", kind: .regex))
    }

    func test_isValid_checksDomain() {
        XCTAssertTrue(URLRule.isValid("github.com", kind: .domain))
        XCTAssertTrue(URLRule.isValid("https://github.com/x", kind: .domain))
        XCTAssertFalse(URLRule.isValid("https://", kind: .domain))
        XCTAssertFalse(URLRule.isValid("*", kind: .domain))
        XCTAssertFalse(URLRule.isValid("*github.com", kind: .domain))
    }

    func test_normalized_keepsOnlyTheDomain() {
        XCTAssertEqual(URLRule.normalized("https://www.GitHub.com/mares29?tab=repos", kind: .domain), "github.com")
        XCTAssertEqual(URLRule.normalized("*.github.com", kind: .domain), "github.com")
        XCTAssertEqual(URLRule.normalized("localhost:3000/admin", kind: .domain), "localhost:3000")
        XCTAssertEqual(URLRule.normalized(".github.com.", kind: .domain), "github.com")
        XCTAssertEqual(URLRule.normalized("http://[::1]:3000/x", kind: .domain), "[::1]:3000")
    }

    func test_normalized_keepsWwwWhenItIsTheWholeDomain() {
        XCTAssertEqual(URLRule.normalized("www.com", kind: .domain), "www.com")
    }

    func test_normalized_onlyTrimsOtherKinds() {
        XCTAssertEqual(URLRule.normalized(" https://GitHub.com/X \n", kind: .contains), "https://GitHub.com/X")
        XCTAssertEqual(URLRule.normalized(" ^https://x ", kind: .regex), "^https://x")
    }

    func test_codable_roundTrips() throws {
        let original = URLRule(kind: .regex, pattern: "zoom\\.us", browserID: "com.apple.Safari", isEnabled: false)
        let decoded = try JSONDecoder().decode(URLRule.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }
}
