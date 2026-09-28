# MiMaps release report

Latest verified signed release workflow: [GitHub Actions run 36347404425](https://github.com/cuonqisme/MiMaps/actions/runs/36347404425).

| Field | Result |
|---|---|
| Application version | 0.1.0 |
| Build number | 7 |
| Verified source commit | `0d57384c730614a4aa78c6c89cff794def60e41b` |
| Xcode | Xcode 26.6 (17F113) |
| Swift | Apple Swift 6.3.3 |
| macOS runner | 26.6.2 (`macos-26`) |
| iOS deployment target | 16.0 |
| Map provider | Apple MapKit (native) |
| Third-party map API key | Not required |
| Simulator build | PASSED |
| Unit tests | PASSED — 54 tests |
| Signed archive | PASSED |
| IPA | PASSED — 2,070,144 bytes |
| IPA artifact | Superseded by the pending MiMaps release |
| IPA SHA-256 | `30e2ff5d7048d2dd8d8a205b2dbc650eae224e32fe4384a2609ed689be6d0f70` |
| Signing method | Manual certificate and Ad Hoc provisioning profile |
| Google SDK entries | 0 |
| Physical iPhone tests | PENDING for this build |
| Mi Band symbols | Basic arrows retained; unsupported glyphs mapped to supported arrows with text labels |

## Automated verification completed

- XcodeGen generation, Swift 6 strict concurrency, simulator build, 54 XCTest cases, signed device archive, Ad Hoc IPA export, checksum, embedded profile, and code-signature structure all passed.
- Route cleanup, preview-notification suppression, mock controls, category-filtered nearby POIs, redesigned search, recent destinations, live traffic, map styles, pin selection, alternate routes, route preferences, live location tracking, step classification, rerouting, Google Maps link parsing, safety-alert formatting, notification thresholds, permissions, and settings persistence are covered by compilation or automated tests.
- Google Maps, Google Places, and Google Navigation dependencies were removed from the application and generated project.

## Physical verification remaining

- Install the next signed MiMaps IPA on the registered iPhone and verify route cleanup, preview notification suppression, mock controls, live Apple Maps search/routing, nearby POIs, recent destinations, traffic, background GPS, lock-screen notifications, Mi Fitness mirroring, and the five fallback maneuver cases on Mi Band 9.
- MapKit has no motorcycle transport mode; motorcycle requests intentionally use an automobile route and display that fallback in the UI.
- MapKit does not provide camera/speed-limit data or an avoid-overpass preference. Safety notification models are ready for a licensed provider, but the app does not fabricate unavailable data.
- Direct Google Maps Share Sheet integration requires a separately provisioned Share Extension bundle ID/profile. Build 7 supports Google Maps copy-link import but intentionally contains no unsigned extension.
