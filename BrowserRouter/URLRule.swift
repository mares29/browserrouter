import Foundation

/// Sends links that match a pattern to a chosen browser, ahead of focus tracking
struct URLRule: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case domain
        case contains
        case regex

        var label: String {
            switch self {
            case .domain: return "Domain"
            case .contains: return "URL contains"
            case .regex: return "URL matches regex"
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var pattern: String
    var browserID: String
    var isEnabled = true

    /// Every kind ignores case; an empty, invalid or runaway pattern matches nothing
    func matches(_ url: URL) -> Bool {
        let pattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return false }

        switch kind {
        case .domain:
            // Parse the link like the pattern, so IDN and IPv6 hosts compare in the same form
            guard let domain = Self.domainParts(pattern),
                  let link = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  var host = link.host?.lowercased()
            else { return false }
            if host.hasSuffix(".") { host.removeLast() }
            // github.com covers gist.github.com, but not notgithub.com
            guard host == domain.host || host.hasSuffix("." + domain.host) else { return false }
            // An explicit :443 or :80 is the same site as no port
            let port = link.port ?? (link.scheme?.lowercased() == "https" ? 443 : 80)
            return domain.port == nil || port == domain.port
        case .contains:
            // Also check the decoded link, so a pattern typed with spaces or accents still matches
            let link = url.absoluteString
            return [link, link.removingPercentEncoding].contains {
                $0?.range(of: pattern, options: .caseInsensitive) != nil
            }
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
            let link = url.absoluteString
            // A pattern that backtracks without end must not hold up every link, so give up after a moment
            let deadline = Date().addingTimeInterval(0.05)
            var matched = false
            regex.enumerateMatches(in: link, options: .reportProgress, range: NSRange(link.startIndex..., in: link)) { result, _, stop in
                matched = result != nil
                if matched || Date() > deadline { stop.pointee = true }
            }
            return matched
        }
    }

    /// Whether the pattern can match anything, so the editor can refuse it
    static func isValid(_ pattern: String, kind: Kind) -> Bool {
        let pattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return false }

        switch kind {
        case .domain: return domainParts(pattern) != nil
        case .contains: return true
        case .regex: return (try? NSRegularExpression(pattern: pattern)) != nil
        }
    }

    /// The pattern as it is saved: a pasted link becomes just its domain
    static func normalized(_ pattern: String, kind: Kind) -> String {
        let pattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard kind == .domain, let domain = domainParts(pattern) else { return pattern }
        return domain.port.map { "\(domain.host):\($0)" } ?? domain.host
    }

    /// Host and optional port of a domain pattern, which may be a pasted link:
    /// "https://www.GitHub.com/mares29" and "*.github.com" both give github.com
    static func domainParts(_ pattern: String) -> (host: String, port: Int?)? {
        var text = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("*.") { text.removeFirst(2) }
        // ".github.com" means the same as "*.github.com"
        while text.hasPrefix(".") { text.removeFirst() }

        guard let components = URLComponents(string: text.contains("://") ? text : "http://" + text),
              var host = components.host
        else { return nil }

        if host.hasSuffix(".") { host.removeLast() }
        // www.github.com should still catch github.com links; www.com stays as it is
        if host.hasPrefix("www."), host.dropFirst(4).contains(".") { host.removeFirst(4) }
        // A wildcard anywhere else can never equal a real host
        guard !host.isEmpty, !host.contains("*") else { return nil }

        return (host, components.port)
    }
}
