# Open Source Release Design

## Goal

Publish BrowserRouter as a transparent, trust-focused open-source project. Users can verify the code and report bugs. Feature requests and PRs not accepted.

## Decisions

| Decision | Choice |
|----------|--------|
| Primary goal | Transparency & trust |
| Community model | Bug reports only |
| License | MIT |
| Privacy docs | Dedicated PRIVACY.md |
| Platform | GitHub (github.com/mares29/browserrouter) |
| Feature requests | Disabled (template-only issues) |

## Files to Add

### 1. LICENSE

Standard MIT license:
- Copyright holder: Karel Mares
- Year: 2025

### 2. PRIVACY.md

Content:
- **Stored:** Browser order list in UserDefaults (local only)
- **Not stored:** No analytics, no network requests, no URL logging, no telemetry
- **Location:** `~/Library/Preferences/com.browserrouter.app.plist`
- **Verification:** Point to `URLHandler.swift`, `BrowserStack.swift`, `Settings.swift`
- **Deletion:** Delete plist or uninstall app

Tone: Direct, technical. Audience is developers verifying claims.

### 3. SECURITY.md

Content:
- Contact: mares.dev@icloud.com
- Scope: URL leakage, unexpected network calls, privilege escalation
- Response: Best effort (solo maintainer)

### 4. .github/ISSUE_TEMPLATE/bug_report.md

Fields:
- macOS version
- Browser(s) involved
- Steps to reproduce
- Expected vs actual behavior
- Installation method (bundle.sh vs other)

### 5. .github/ISSUE_TEMPLATE/config.yml

```yaml
blank_issues_enabled: false
```

No feature request template. Only bug reports accepted.

## Files to Update

### README.md

Add after description:
- One-liner: "Fully open source - verify the code yourself"
- One-liner: "Built with [Claude Code](https://claude.ai/code)"
- Privacy section linking to PRIVACY.md

Verify GitHub URL matches actual repo.

## GitHub Settings (Manual)

After pushing:
- Disable: Wiki, Discussions, Projects
- Keep enabled: Issues (bugs via template only)
- PRs: Leave enabled, don't merge external

## Out of Scope

- CONTRIBUTING.md (not accepting contributions)
- CHANGELOG.md (not needed for trust goal)
- CI/CD (nice-to-have, not required for transparency)
- Code of Conduct (minimal community interaction)

## Implementation Order

1. Add LICENSE
2. Add PRIVACY.md
3. Add SECURITY.md
4. Add .github/ISSUE_TEMPLATE/bug_report.md
5. Add .github/ISSUE_TEMPLATE/config.yml
6. Update README.md
7. Commit and push
8. Configure GitHub settings manually
