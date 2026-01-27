import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var stack: BrowserStack
    var onOpenSettings: () -> Void

    @State private var detectedBrowsers: [Browser] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)

            sectionHeader("Tracked Browsers")

            browserList
                .padding(.bottom, 12)

            Divider()
                .padding(.vertical, 8)

            bottomActions
        }
        .padding(16)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .onAppear {
            detectedBrowsers = BrowserDetector.detectBrowsers()
            if settings.fallbackBrowser == nil, let first = detectedBrowsers.first {
                settings.fallbackBrowser = first.bundleID
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BrowserRouter")
                .font(.headline)

            if let currentID = stack.mostRecent,
               let browser = detectedBrowsers.first(where: { $0.bundleID == currentID }) {
                Text("Opening links in \(browser.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No browser selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)
    }

    private var browserList: some View {
        VStack(spacing: 0) {
            ForEach(detectedBrowsers) { browser in
                browserRow(browser)
            }
        }
    }

    private func browserRow(_ browser: Browser) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: browser.icon)
                .resizable()
                .frame(width: 20, height: 20)

            Text(browser.name)
                .font(.body)

            Spacer()

            Toggle("", isOn: binding(for: browser.bundleID))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var bottomActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("BrowserRouter Settings...") {
                onOpenSettings()
            }
            .buttonStyle(.plain)

            Button("Quit BrowserRouter") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
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
}
