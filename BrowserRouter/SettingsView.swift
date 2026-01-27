import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var stack: BrowserStack

    @State private var detectedBrowsers: [Browser] = []
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            browserList
            fallbackPicker
            Divider()
            displayModePicker
            Divider()
            launchAtLoginToggle
            Divider()
            actions
            Divider()
            Button("Quit BrowserRouter") {
                NSApp.terminate(nil)
            }
            .foregroundColor(.red)
        }
        .padding()
        .onAppear { detectedBrowsers = BrowserDetector.detectBrowsers() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BrowserRouter")
                .font(.headline)

            if let current = stack.mostRecent,
               let browser = detectedBrowsers.first(where: { $0.bundleID == current }) {
                Text("Current: \(browser.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var browserList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track these browsers:")
                .font(.subheadline)

            ForEach(detectedBrowsers) { browser in
                Toggle(browser.name, isOn: binding(for: browser.bundleID))
            }
        }
    }

    private var fallbackPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fallback browser:")
                .font(.subheadline)

            Picker("", selection: $settings.fallbackBrowser) {
                Text("System Default").tag(nil as String?)
                ForEach(detectedBrowsers) { browser in
                    Text(browser.name).tag(browser.bundleID as String?)
                }
            }
            .labelsHidden()
        }
    }

    private var launchAtLoginToggle: some View {
        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin },
            set: { newValue in
                toggleLaunchAtLogin(newValue)
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        ))
    }

    private var displayModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu bar display:")
                .font(.subheadline)

            Picker("", selection: $settings.menuBarDisplayMode) {
                ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var actions: some View {
        HStack {
            Button("Rescan Browsers") {
                detectedBrowsers = BrowserDetector.detectBrowsers()
            }

            Spacer()

            Button("Set as Default Browser") {
                setAsDefaultBrowser()
            }
        }
    }

    private func binding(for bundleID: String) -> Binding<Bool> {
        Binding(
            get: { settings.trackedBrowsers.contains(bundleID) },
            set: { isTracked in
                if isTracked {
                    settings.trackedBrowsers.append(bundleID)
                } else {
                    settings.trackedBrowsers.removeAll { $0 == bundleID }
                }
            }
        )
    }

    private func setAsDefaultBrowser() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID as CFString)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
}
