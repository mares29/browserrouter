import Foundation

final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    private enum Keys {
        static let trackedBrowsers = "trackedBrowsers"
        static let fallbackBrowser = "fallbackBrowser"
    }

    @Published var trackedBrowsers: [String] {
        didSet { defaults.set(trackedBrowsers, forKey: Keys.trackedBrowsers) }
    }

    @Published var fallbackBrowser: String? {
        didSet { defaults.set(fallbackBrowser, forKey: Keys.fallbackBrowser) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.trackedBrowsers = defaults.stringArray(forKey: Keys.trackedBrowsers) ?? []
        self.fallbackBrowser = defaults.string(forKey: Keys.fallbackBrowser)
    }
}
