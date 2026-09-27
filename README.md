# MiBand Navigator

MiBand Navigator is a SwiftUI iPhone application that owns a Google Navigation SDK session and mirrors concise turn instructions to a Xiaomi Smart Band 9 through normal iOS notifications and Mi Fitness. Version 1 does not use proprietary Xiaomi BLE.

## Current status

Simulator builds and tests run on GitHub-hosted macOS because the primary development environment is Windows. The release workflow always supports an unsigned archive validation and produces a signed IPA when Apple signing secrets are configured.

## Windows quick start

```powershell
git clone https://github.com/cuonqisme/MiMaps.git
cd MiMaps
git checkout -b feature/my-change
# Edit in VS Code, then:
git add -A
git commit -m "feat: describe the change"
git push -u origin feature/my-change
```

Open the repository's **Actions** tab and inspect **iOS CI**. The workflow generates the Xcode project from `project.yml`, builds for an iPhone simulator, and runs XCTest without signing.

Never commit API keys or Apple signing material. Google Maps Platform setup, key restrictions, signed IPA, and TestFlight steps are documented as their implementation milestones land.

Setup guides: [Windows development](WINDOWS_DEVELOPMENT.md), [Google Cloud](GOOGLE_CLOUD_SETUP.md), [Apple signing](APPLE_SIGNING.md), [GitHub Actions](GITHUB_ACTIONS_SETUP.md), [IPA build](IPA_BUILD.md), [TestFlight](TESTFLIGHT.md), [testing](TESTING.md), [hardware testing](HARDWARE_TESTING.md), [privacy](PRIVACY.md), and [security](SECURITY.md).

Latest automated status and physical-verification boundaries are recorded in [RELEASE_REPORT.md](RELEASE_REPORT.md).

## Supported toolchain

- Xcode 26.6 / Swift 6.2 on GitHub `macos-26`
- iOS 16.0 minimum deployment target
- XcodeGen 2.44.1
- Swift Package Manager only

## Generate the project on macOS

```bash
brew install xcodegen
scripts/ci/bootstrap.sh
open MiBandNavigator.xcodeproj
```

The generated `.xcodeproj` is intentionally ignored; `project.yml` is the source of truth.
