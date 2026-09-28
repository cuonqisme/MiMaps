# API compatibility

Verified against the current project and official platform documentation on 2026-09-28.

| Area | Selected baseline | Notes |
|---|---|---|
| Apple toolchain | Xcode 26.6, Swift 6.2 | CI selects Xcode explicitly through `DEVELOPER_DIR`. |
| Deployment target | iOS 16.0 | Required by the current SwiftUI implementation and release configuration. |
| GitHub runner | `macos-26` | Used for XcodeGen, simulator tests, archives, and signed IPA export. |
| Map and place search | Apple MapKit | Native framework; no third-party package or API key is required. |
| Live location | Apple Core Location | Enabled for active guidance and stopped when navigation ends or arrives. |
| Wearable delivery | UserNotifications + Mi Fitness mirroring | No proprietary Xiaomi BLE connection is used. |

MapKit route calculation supports automobile, walking, and transit. It has no motorcycle route type, so a motorcycle request is explicitly labelled as an automobile fallback. MapKit also does not provide speed-camera data or a dedicated avoid-overpass option.

MapKit directions, location updates, and mock instructions feed the same `NavigationCoordinator`, threshold/cooldown policy, deduplicator, and `NotificationBandTransport`. Simulator CI verifies the provider-neutral logic; live routing, background GPS, Mi Fitness mirroring, and band rendering still require physical-device testing.

Sygic is only an evaluated future provider. Its public iOS documentation confirms safety warnings but does not publicly guarantee motorcycle routing for Vietnam. See [SYGIC_EVALUATION.md](SYGIC_EVALUATION.md).

## Official references

- Apple MapKit: https://developer.apple.com/documentation/mapkit
- Apple Core Location: https://developer.apple.com/documentation/corelocation
- Apple UserNotifications: https://developer.apple.com/documentation/usernotifications
- Apple Xcode release notes: https://developer.apple.com/documentation/xcode-release-notes
- GitHub macOS 26 image: https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md
