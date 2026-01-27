import SwiftUI
import ServiceManagement

struct FirstLaunchView: View {
    @ObservedObject var settings: AppSettings
    var onComplete: () -> Void

    @State private var detectedBrowsers: [Browser] = []
    @State private var selectedBrowsers: Set<String> = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to BrowserRouter")
                .font(.title)

            Text("Select the browsers you want to track:")
                .font(.subheadline)

            List(detectedBrowsers, selection: $selectedBrowsers) { browser in
                Text(browser.name)
            }
            .frame(height: 200)

            HStack {
                Button("Skip") {
                    onComplete()
                }

                Spacer()

                Button("Continue") {
                    settings.trackedBrowsers = Array(selectedBrowsers)
                    promptForDefaultBrowser()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            detectedBrowsers = BrowserDetector.detectBrowsers()
            // Pre-select common browsers
            let common: Set<String> = ["com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser"]
            selectedBrowsers = common.intersection(Set(detectedBrowsers.map(\.bundleID)))
        }
    }

    private func promptForDefaultBrowser() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID as CFString)
    }
}
