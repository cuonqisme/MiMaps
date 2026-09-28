# MiBand Navigator

MiBand Navigator is a SwiftUI iPhone application that uses Apple MapKit for search, route calculation, live step tracking, and rerouting. Concise turn instructions are mirrored to a Xiaomi Smart Band 9 through normal iOS notifications and Mi Fitness. The app does not use proprietary Xiaomi BLE.

The current MapKit build includes:

- Standard, muted, satellite, and hybrid map styles.
- Car, walking, public-transit, and motorcycle-request modes. MapKit has no motorcycle transport type, so motorcycle requests visibly fall back to an automobile route.
- Alternative routes with distance, ETA, advantages, disadvantages, toll, and highway indicators.
- Avoid-toll and avoid-highway preferences.
- Nearby food, fuel, parking, hospital, pharmacy, ATM, coffee, and hotel search with a draggable, distance-sorted result sheet and route/call/website/share actions.
- Live Apple Maps traffic display and an eight-item local recent-destination history.
- Tap-to-select Apple map places, long-press pinning, routing to nearby results, and an unobstructed heading-reset control.
- Google Maps link import through the clipboard, including shortened `maps.app.goo.gl` links.
- Current GPS speed on the phone and provider-neutral speed-limit/safety-camera notification models for a future licensed data provider.
- Professional SF Symbols on the iPhone while Mi Band notifications use only the verified-safe `↑`, `←`, `→`, `↖`, `↗`, and `●` character set plus Vietnamese maneuver text.

MapKit does not supply motorcycle-specific routes, speed-camera data, or a dedicated avoid-overpass option. The app never fabricates these values. Sygic's iOS SDK publicly documents speed-limit, camera, incident, railway-crossing, and sharp-curve alerts, but its public routing documentation does not guarantee motorcycle routing. Integration requires a commercial Sygic SDK license/key and confirmation of motorcycle and safety-data coverage for Vietnam; see [the Sygic evaluation](docs/SYGIC_EVALUATION.md).

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

Never commit Apple signing material. Native MapKit does not require a third-party API key. Direct appearance in the iOS share sheet requires a separately provisioned Share Extension bundle ID and provisioning profile; the current signed target instead supports Google Maps **Share → Copy link → Paste Google Maps link**.

Setup guides: [Windows development](WINDOWS_DEVELOPMENT.md), [Apple signing](APPLE_SIGNING.md), [GitHub Actions](GITHUB_ACTIONS_SETUP.md), [IPA build](IPA_BUILD.md), [TestFlight](TESTFLIGHT.md), [testing](TESTING.md), [hardware testing](HARDWARE_TESTING.md), [privacy](PRIVACY.md), and [security](SECURITY.md).

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
