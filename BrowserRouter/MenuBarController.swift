import SwiftUI
import AppKit
import Combine

final class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    private let settings: AppSettings
    private let stack: BrowserStack
    private let browsers: [Browser]

    @Published var currentBrowser: String?

    init(settings: AppSettings, stack: BrowserStack, browsers: [Browser]) {
        self.settings = settings
        self.stack = stack
        self.browsers = browsers
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        // Observe browser stack changes
        stack.$browsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)

        // Observe display mode changes
        settings.$menuBarDisplayMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)
    }

    func setup(settingsView: some View) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "BrowserRouter")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: settingsView)

        updateTitle()
    }

    private func updateTitle() {
        guard let button = statusItem?.button else { return }

        guard let bundleID = stack.mostRecent,
              let browser = browsers.first(where: { $0.bundleID == bundleID }) else {
            button.title = ""
            return
        }

        switch settings.menuBarDisplayMode {
        case .iconOnly:
            button.title = ""
        case .iconAndLetter:
            button.title = " \(browser.name.prefix(1))"
        case .iconAndName:
            button.title = " \(browser.name)"
        }
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
