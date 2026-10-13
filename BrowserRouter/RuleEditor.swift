import AppKit

/// Modal dialog that adds or edits a rule
final class RuleEditor: NSObject, NSTextFieldDelegate {
    private let rule: URLRule

    private let alert = NSAlert()
    private let kindPopup = NSPopUpButton()
    private let patternField = NSTextField(string: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let browserPopup = NSPopUpButton()
    private var saveButton: NSButton!

    /// `browsers` are offered as targets; the rule's own browser is kept even if it is missing
    init(rule: URLRule, browsers: [Browser], isNew: Bool) {
        self.rule = rule
        super.init()

        alert.messageText = isNew ? "Add Rule" : "Edit Rule"
        alert.informativeText = "Matching links open in the browser you choose here, instead of the one you used last."
        saveButton = alert.addButton(withTitle: isNew ? "Add" : "Save")
        alert.addButton(withTitle: "Cancel")

        for kind in URLRule.Kind.allCases {
            kindPopup.addItem(withTitle: kind.label)
            kindPopup.lastItem?.representedObject = kind.rawValue
        }
        kindPopup.selectItem(at: URLRule.Kind.allCases.firstIndex(of: rule.kind) ?? 0)
        kindPopup.target = self
        kindPopup.action = #selector(kindChanged)

        patternField.stringValue = rule.pattern
        patternField.delegate = self
        // Long links and regexes scroll instead of wrapping out of sight
        patternField.usesSingleLineMode = true
        patternField.widthAnchor.constraint(equalToConstant: 280).isActive = true

        hintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.lineBreakMode = .byTruncatingTail

        // Added as menu items, since addItem(withTitle:) drops an earlier browser with the same name
        for browser in browsers {
            let item = NSMenuItem(title: browser.name, action: nil, keyEquivalent: "")
            item.representedObject = browser.bundleID
            item.image = Self.menuIcon(browser.icon)
            browserPopup.menu?.addItem(item)
        }
        if !browsers.contains(where: { $0.bundleID == rule.browserID }) {
            browserPopup.addItem(withTitle: "\(rule.browserID) (not installed)")
            browserPopup.lastItem?.representedObject = rule.browserID
        }
        browserPopup.selectItem(at: browserPopup.indexOfItem(withRepresentedObject: rule.browserID))

        alert.accessoryView = makeForm()
        update()
    }

    /// The rule as saved, or nil if the user cancelled
    func run() -> URLRule? {
        alert.layout()
        alert.window.initialFirstResponder = patternField
        // A menu bar app isn't frontmost, so bring the dialog forward
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        var saved = rule
        saved.kind = selectedKind
        saved.pattern = URLRule.normalized(patternField.stringValue, kind: selectedKind)
        saved.browserID = browserPopup.selectedItem?.representedObject as? String ?? rule.browserID
        return saved
    }

    private var selectedKind: URLRule.Kind {
        (kindPopup.selectedItem?.representedObject as? String).flatMap(URLRule.Kind.init(rawValue:)) ?? rule.kind
    }

    private func makeForm() -> NSView {
        let grid = NSGridView(views: [
            [Self.label("Match:"), kindPopup],
            [Self.label("Pattern:"), patternField],
            [NSGridCell.emptyContentView, hintLabel],
            [Self.label("Open in:"), browserPopup],
        ])
        grid.rowSpacing = 4
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        // The hint sits right under its field; the other rows keep a wider gap
        grid.row(at: 1).topPadding = 4
        grid.row(at: 3).topPadding = 4
        grid.frame.size = grid.fittingSize
        return grid
    }

    // MARK: - Validation

    func controlTextDidChange(_ obj: Notification) {
        update()
    }

    @objc private func kindChanged() {
        update()
    }

    /// Explains the chosen kind, flags a bad pattern, and only allows saving one that can match
    private func update() {
        let kind = selectedKind
        let pattern = patternField.stringValue
        let isValid = URLRule.isValid(pattern, kind: kind)

        patternField.placeholderString = kind.placeholder
        saveButton.isEnabled = isValid

        let showError = !isValid && !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        hintLabel.stringValue = showError ? kind.invalidHint : kind.hint
        hintLabel.textColor = showError ? .systemRed : .secondaryLabelColor
    }

    private static func label(_ title: String) -> NSTextField {
        NSTextField(labelWithString: title)
    }

    private static func menuIcon(_ icon: NSImage) -> NSImage? {
        let small = icon.copy() as? NSImage
        small?.size = NSSize(width: 16, height: 16)
        return small
    }
}

private extension URLRule.Kind {
    var placeholder: String {
        switch self {
        case .domain: return "github.com"
        case .contains: return "meet.google.com"
        case .regex: return #"^https://[^/]+\.zoom\.us/j/"#
        }
    }

    var hint: String {
        switch self {
        case .domain: return "Also matches subdomains, like gist.github.com"
        case .contains: return "Matches text anywhere in the link, ignoring case"
        case .regex: return "Searched anywhere in the link, ignoring case"
        }
    }

    var invalidHint: String {
        switch self {
        case .domain: return "Enter a domain, like github.com"
        case .contains: return hint
        case .regex: return "Not a valid regular expression"
        }
    }
}
