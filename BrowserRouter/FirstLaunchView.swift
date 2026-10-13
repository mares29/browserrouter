import SwiftUI

struct FirstLaunchView: View {
    @ObservedObject var settings: AppSettings
    let browsers: [Browser]
    /// System default browser before BrowserRouter took over
    let previousDefault: String?
    var onComplete: () -> Void

    @State private var selectedBrowsers: Set<String> = []

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Welcome to BrowserRouter")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select the browsers you want to track")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("BROWSERS")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(browsers) { browser in
                        browserRow(browser)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button("Skip") {
                    onComplete()
                }

                Spacer()

                Button("Continue") {
                    let selected = browsers.map(\.bundleID).filter { selectedBrowsers.contains($0) }
                    settings.trackedBrowsers = selected
                    settings.fallbackBrowser = URLHandler.defaultFallback(previousDefault: previousDefault, selected: selected, installed: browsers.map(\.bundleID))

                    BrowserDetector.setSelfAsDefault()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            selectedBrowsers = Set(BrowserDetector.commonBrowserIDs).intersection(browsers.map(\.bundleID))
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

            Toggle("", isOn: Binding(
                get: { selectedBrowsers.contains(browser.bundleID) },
                set: { selected in
                    if selected {
                        selectedBrowsers.insert(browser.bundleID)
                    } else {
                        selectedBrowsers.remove(browser.bundleID)
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
