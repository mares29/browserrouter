# Release Process Design

## Goal

Automated release via GitHub Actions. Push a version tag → workflow builds, zips, and creates GitHub Release.

## Decisions

| Decision | Choice |
|----------|--------|
| Signing | None (no Apple Developer account) |
| Distribution format | ZIP only |
| Automation | GitHub Actions |
| Versioning | Semantic (v1.0.0) |

## Workflow

```
git tag v1.0.0 -m "Initial release"
git push origin v1.0.0
    ↓
GitHub Actions triggers on v* tag
    ↓
Checkout → Build → Bundle .app → Zip → Create Release
```

## Files to Add

### 1. .github/workflows/release.yml

```yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: macos-latest
    steps:
      - Checkout code
      - Build: swift build -c release
      - Create .app bundle
      - Zip: BrowserRouter-vX.X.X.zip
      - Create GitHub Release with softprops/action-gh-release
```

### 2. scripts/release.sh

Standalone script:
- Builds release binary
- Creates .app bundle (reuses bundle.sh logic)
- Zips to build/BrowserRouter-vX.X.X.zip
- Works locally and in CI

## Files to Update

### README.md

Add "Download" section:
- Link to GitHub Releases
- Gatekeeper bypass instructions (right-click → Open)

## Output

- Tag: `v1.0.0`
- Zip: `BrowserRouter-v1.0.0.zip`
- Contents: `BrowserRouter.app`

## User Experience

Users will see Gatekeeper warning on first launch:
> "BrowserRouter can't be opened because Apple cannot check it for malicious software"

Bypass: Right-click → Open → Open (in dialog)

Or: System Settings → Privacy & Security → "Open Anyway"

## Implementation Order

1. Create scripts/release.sh
2. Create .github/workflows/release.yml
3. Update README.md with download section
4. Test locally with scripts/release.sh
5. Commit and push
6. Create first release: git tag v1.0.0 && git push origin v1.0.0
