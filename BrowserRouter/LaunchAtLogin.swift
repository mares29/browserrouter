import ServiceManagement

/// Opening BrowserRouter at login, through the system's Login Items
enum LaunchAtLogin {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isEnabled: Bool { status == .enabled }

    /// Turning it on can leave it waiting for the user's approval, so that opens System Settings
    static func setEnabled(_ enabled: Bool) throws {
        switch (enabled, status) {
        case (true, .enabled), (false, .notRegistered), (false, .notFound):
            return
        case (true, .requiresApproval):
            // Already registered; only the user can approve it
            SMAppService.openSystemSettingsLoginItems()
        case (true, _):
            try SMAppService.mainApp.register()
            if status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        case (false, _):
            try SMAppService.mainApp.unregister()
        }
    }
}
