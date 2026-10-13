import SwiftUI
import os

/// The welcome window: what BrowserRouter does, which browsers it follows,
/// making it the default browser, and where to find it afterwards
struct FirstLaunchView: View {
    enum Step: Int, CaseIterable {
        case welcome, browsers, defaultBrowser, done
    }

    private static let logger = Logger(subsystem: "com.browserrouter.app", category: "FirstLaunchView")

    @ObservedObject var settings: AppSettings
    let browsers: [Browser]
    var onComplete: () -> Void

    @State private var step = Step.welcome
    @State private var selectedBrowsers: Set<String> = []
    @State private var fallbackBrowser: String?
    @State private var isDefault = BrowserDetector.isSelfDefault()
    @State private var currentDefault = BrowserDetector.systemDefaultBrowserName()
    /// macOS kept another browser after we asked
    @State private var defaultDeclined = false
    @State private var isSettingDefault = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome:
                    WelcomeStep()
                case .browsers:
                    BrowsersStep(browsers: browsers, selected: $selectedBrowsers, fallback: $fallbackBrowser)
                case .defaultBrowser:
                    DefaultBrowserStep(isDefault: isDefault, declined: defaultDeclined, currentDefault: currentDefault)
                case .done:
                    DoneStep(isDefault: isDefault, launchAtLogin: launchAtLoginBinding)
                }
            }
            .id(step)
            .transition(.opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        // The transparent title bar already insets the top
        .padding(EdgeInsets(top: 8, leading: 32, bottom: 20, trailing: 32))
        .frame(width: 460, height: 500)
        .onAppear {
            // Seeded on first launch, so closing the window early still leaves a working setup
            selectedBrowsers = Set(settings.trackedBrowsers)
            fallbackBrowser = settings.fallbackBrowser
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Both can also change in System Settings
            refreshDefault()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            StepDots(current: step)

            Spacer()

            if step != .welcome {
                Button("Back") { go(to: Step(rawValue: step.rawValue - 1)) }
            }

            if step == .defaultBrowser && !isDefault {
                Button("Not Now") { go(to: .done) }
            }

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled((step == .browsers && selectedBrowsers.isEmpty) || isSettingDefault)
        }
        .controlSize(.large)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return "Get Started"
        case .browsers: return "Continue"
        case .defaultBrowser: return isDefault ? "Continue" : "Set as Default Browser"
        case .done: return "Done"
        }
    }

    private func primaryAction() {
        switch step {
        case .welcome:
            go(to: .browsers)
        case .browsers:
            saveBrowsers()
            go(to: .defaultBrowser)
        case .defaultBrowser:
            if isDefault {
                go(to: .done)
            } else {
                setDefault()
            }
        case .done:
            onComplete()
        }
    }

    private func go(to next: Step?) {
        guard let next else { return }
        withAnimation(.easeInOut(duration: 0.2)) { step = next }
    }

    // MARK: - Actions

    private func saveBrowsers() {
        // In list order, so the menus match. A tracked browser the list doesn't show stays tracked.
        let listed = Set(browsers.map(\.bundleID))
        settings.trackedBrowsers = browsers.map(\.bundleID).filter { selectedBrowsers.contains($0) }
            + settings.trackedBrowsers.filter { !listed.contains($0) }
        settings.fallbackBrowser = fallbackBrowser
    }

    private func setDefault() {
        isSettingDefault = true
        BrowserDetector.setSelfAsDefault { isNowDefault in
            isSettingDefault = false
            // Trust the answer; looking it up again right away can still show the old default
            isDefault = isNowDefault
            currentDefault = BrowserDetector.systemDefaultBrowserName()
            defaultDeclined = !isNowDefault
        }
    }

    private func refreshDefault() {
        isDefault = BrowserDetector.isSelfDefault()
        currentDefault = BrowserDetector.systemDefaultBrowserName()
        if isDefault { defaultDeclined = false }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            launchAtLogin
        } set: { enabled in
            do {
                try LaunchAtLogin.setEnabled(enabled)
            } catch {
                Self.logger.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
            }
            // Turning it on can still be waiting for approval in System Settings
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            StepHeader(
                title: "Links follow your focus",
                text: "Click a link in any app and it opens in the browser you were last using."
            )

            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(symbol: "macwindow.on.rectangle", title: "Use your browsers as usual", text: "BrowserRouter notices which one you switch to.")
                FeatureRow(symbol: "link", title: "Click links anywhere", text: "Links from Mail, Slack, Notes and other apps follow you.")
                FeatureRow(symbol: "line.3.horizontal.decrease.circle", title: "Add rules when you need them", text: "Send chosen sites to a browser of your choice.")
            }
            .padding(.top, 8)
        }
    }
}

private struct BrowsersStep: View {
    let browsers: [Browser]
    @Binding var selected: Set<String>
    @Binding var fallback: String?

    var body: some View {
        VStack(spacing: 18) {
            StepHeader(
                title: "Which browsers do you use?",
                text: "BrowserRouter follows the ones you switch between."
            )

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(browsers) { browser in
                        row(browser)
                        if browser != browsers.last {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            // Only as tall as the list, until it needs to scroll
            .frame(height: min(CGFloat(browsers.count) * 37, 222))
            .card()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Fallback browser")
                    Spacer()
                    Picker("Fallback browser", selection: $fallback) {
                        ForEach(browsers) { browser in
                            Text(browser.name).tag(Optional(browser.bundleID))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Text(selected.isEmpty ? "Turn on at least one browser above." : "Opens links when none of the browsers above is running.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .card()
        }
    }

    private func row(_ browser: Browser) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: browser.icon)
                .resizable()
                .frame(width: 22, height: 22)

            Text(browser.name)

            Spacer()

            Toggle(browser.name, isOn: Binding(
                get: { selected.contains(browser.bundleID) },
                set: { isOn in
                    if isOn {
                        selected.insert(browser.bundleID)
                    } else {
                        selected.remove(browser.bundleID)
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .frame(height: 36)
    }
}

private struct DefaultBrowserStep: View {
    let isDefault: Bool
    let declined: Bool
    let currentDefault: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.accentColor)
                .frame(height: 96)

            StepHeader(
                title: "Make BrowserRouter your default browser",
                text: "macOS sends every link to your default browser. BrowserRouter takes its place and passes each link on to the right browser."
            )

            Group {
                if isDefault {
                    Label("BrowserRouter is your default browser", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if declined {
                    VStack(spacing: 8) {
                        Label("macOS kept \(currentDefault ?? "your current browser")", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Try again, or choose BrowserRouter later in System Settings › Desktop & Dock.")
                            .foregroundStyle(.secondary)
                        Button("Open System Settings") {
                            BrowserDetector.openDefaultBrowserSettings()
                        }
                        .buttonStyle(.link)
                    }
                } else {
                    VStack(spacing: 8) {
                        if let currentDefault {
                            Text("Your default browser is \(currentDefault).")
                        }
                        Text("macOS will ask you to confirm the change.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
        }
    }
}

private struct DoneStep: View {
    let isDefault: Bool
    @Binding var launchAtLogin: Bool

    var body: some View {
        VStack(spacing: 20) {
            MenuBarPreview()
                .frame(height: 96)

            if isDefault {
                StepHeader(
                    title: "You're all set",
                    text: "BrowserRouter runs in your menu bar. Click its icon to see where links are going, change browsers, or add rules."
                )
            } else {
                StepHeader(
                    title: "BrowserRouter is in your menu bar",
                    text: "Links reach it once it's your default browser. Choose Set as Default Browser in its menu whenever you're ready."
                )
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open at login")
                    Text("Keeps following your browsers after a restart.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Open at login", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(12)
            .card()
            .padding(.top, 8)
        }
    }
}

// MARK: - Pieces

private extension View {
    /// The rounded panel lists and options sit on
    func card() -> some View {
        background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct StepHeader: View {
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(text)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A sketch of the menu bar with BrowserRouter's icon picked out
private struct MenuBarPreview: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.tertiary)
                    .frame(width: 8, height: 8)
            }

            Group {
                if let icon = MenuBarController.menuBarIcon() {
                    Image(nsImage: icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 18, height: 18)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.25), in: RoundedRectangle(cornerRadius: 5))

            Text("9:41")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 34)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

private struct StepDots: View {
    let current: FirstLaunchView.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(FirstLaunchView.Step.allCases, id: \.self) { step in
                Circle()
                    .fill(step == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current.rawValue + 1) of \(FirstLaunchView.Step.allCases.count)")
    }
}
