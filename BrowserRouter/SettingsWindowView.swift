import SwiftUI
import ServiceManagement

struct SettingsWindowView: View {
    @ObservedObject var settings: AppSettings
    @State private var detectedBrowsers: [Browser] = []
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Picker("Fallback Browser", selection: $settings.fallbackBrowser) {
                    ForEach(detectedBrowsers) { browser in
                        HStack {
                            Image(nsImage: browser.icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(browser.name)
                        }
                        .tag(browser.bundleID as String?)
                    }
                }

                Picker("Menu Bar Display", selection: $settings.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        toggleLaunchAtLogin(newValue)
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                ))
            }

            Section("Actions") {
                HStack {
                    Spacer()
                    Button("Rescan Browsers") {
                        detectedBrowsers = BrowserDetector.detectBrowsers()
                    }
                    Spacer()
                }

                HStack {
                    Spacer()
                    Button("Set as Default Browser") {
                        setAsDefaultBrowser()
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 250)
        .onAppear {
            detectedBrowsers = BrowserDetector.detectBrowsers()
        }
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
