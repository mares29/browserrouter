import Foundation

enum MenuBarDisplayMode: Int, CaseIterable {
    case iconOnly = 0
    case iconAndLetter = 1
    case iconAndName = 2

    var label: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .iconAndLetter: return "Icon + letter"
        case .iconAndName: return "Icon + name"
        }
    }
}

final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    private enum Keys {
        static let trackedBrowsers = "trackedBrowsers"
        static let fallbackBrowser = "fallbackBrowser"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let rules = "rules"
    }

    @Published var trackedBrowsers: [String] {
        didSet { defaults.set(trackedBrowsers, forKey: Keys.trackedBrowsers) }
    }

    @Published var fallbackBrowser: String? {
        didSet { defaults.set(fallbackBrowser, forKey: Keys.fallbackBrowser) }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode) }
    }

    /// Checked in order before focus tracking; the first match picks the browser
    @Published var rules: [URLRule] {
        didSet { defaults.set(try? JSONEncoder().encode(rules), forKey: Keys.rules) }
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.trackedBrowsers = defaults.stringArray(forKey: Keys.trackedBrowsers) ?? []
        self.fallbackBrowser = defaults.string(forKey: Keys.fallbackBrowser)
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: defaults.integer(forKey: Keys.menuBarDisplayMode)) ?? .iconOnly
        self.rules = defaults.data(forKey: Keys.rules).flatMap { try? JSONDecoder().decode([URLRule].self, from: $0) } ?? []
    }
}
