# MiBand Navigator release report

Latest verified signed release workflow: [GitHub Actions run 36344362317](https://github.com/cuonqisme/MiMaps/actions/runs/36344362317).

| Field | Result |
|---|---|
| Application version | 0.1.0 |
| Build number | 6 |
| Verified source commit | `65a40b53666e8ac99a7978866697db4df928d236` |
| Xcode | Xcode 26.6 (17F113) |
| Swift | Apple Swift 6.3.3 |
| macOS runner | 26.6.2 (`macos-26`) |
| iOS deployment target | 16.0 |
| Map provider | Apple MapKit (native) |
| Third-party map API key | Not required |
| Simulator build | PASSED |
| Unit tests | PASSED — 53 tests |
| Signed archive | PASSED |
| IPA | PASSED — 2,037,506 bytes |
| IPA artifact | `MiBandNavigator-release-6` |
| IPA SHA-256 | `db86863e37ec7b9e6cdd6ae6dd6899d20131154ee737e2918b1b33e342b4ae9b` |
| Signing method | Manual certificate and Ad Hoc provisioning profile |
| Google SDK entries | 0 |
| Physical iPhone tests | PENDING for this build |
| Mi Band symbols | Basic arrows retained; unsupported glyphs mapped to supported arrows with text labels |

## Automated verification completed

- XcodeGen generation, Swift 6 strict concurrency, simulator build, 53 XCTest cases, signed device archive, Ad Hoc IPA export, checksum, embedded profile, and code-signature structure all passed.
- MapKit search, map styles, nearby POIs, pin selection, alternate routes, route preferences, route display, live location tracking, step classification, rerouting pipeline, Google Maps link parsing, safety-alert formatting, notification thresholds, permissions, and settings persistence are covered by compilation or automated tests.
- Google Maps, Google Places, and Google Navigation dependencies were removed from the application and generated project.

## Physical verification remaining

- Install `artifacts/MiBandNavigator-AdvancedMap.ipa` on the registered iPhone and verify live Apple Maps search/routing, nearby POIs, alternate route selection, background GPS, lock-screen notifications, Mi Fitness mirroring, and the five fallback maneuver cases on Mi Band 9.
- MapKit has no motorcycle transport mode; motorcycle requests intentionally use an automobile route and display that fallback in the UI.
- MapKit does not provide camera/speed-limit data or an avoid-overpass preference. Safety notification models are ready for a licensed provider, but the app does not fabricate unavailable data.
