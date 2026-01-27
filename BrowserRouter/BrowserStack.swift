import Foundation

final class BrowserStack: ObservableObject {
    private let defaults: UserDefaults
    private let key = "browserFocusStack"
    private let maxSize = 10

    @Published private(set) var browsers: [String]

    var mostRecent: String? { browsers.first }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.browsers = defaults.stringArray(forKey: key) ?? []
    }

    func recordFocus(_ bundleID: String) {
        browsers.removeAll { $0 == bundleID }
        browsers.insert(bundleID, at: 0)

        if browsers.count > maxSize {
            browsers = Array(browsers.prefix(maxSize))
        }

        defaults.set(browsers, forKey: key)
    }
}
