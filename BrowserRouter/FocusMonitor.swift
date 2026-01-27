import Foundation
import AppKit

final class FocusMonitor {
    private let settings: AppSettings
    private let stack: BrowserStack
    private var observation: NSObjectProtocol?

    init(settings: AppSettings, stack: BrowserStack) {
        self.settings = settings
        self.stack = stack
    }

    func start() {
        observation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleActivation(notification)
        }
    }

    func stop() {
        if let observation {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
        }
        observation = nil
    }

    private func handleActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier
        else { return }

        // Only track browsers the user has selected
        guard settings.trackedBrowsers.contains(bundleID) else { return }

        stack.recordFocus(bundleID)
    }
}
