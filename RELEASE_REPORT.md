# MiBand Navigator release report

Latest verified signed release workflow: [GitHub Actions run 36340664570](https://github.com/cuonqisme/MiMaps/actions/runs/36340664570).

| Field | Result |
|---|---|
| Application version | 0.1.0 |
| Build number | 5 |
| Verified source commit | `2bf41039ff359b06f54966dbc5dbee9b40e55168` |
| Xcode | Xcode 26.6 (17F113) |
| Swift | Apple Swift 6.3.3 |
| macOS runner | 26.6.2 (`macos-26`) |
| iOS deployment target | 16.0 |
| Map provider | Apple MapKit (native) |
| Third-party map API key | Not required |
| Simulator build | PASSED |
| Unit tests | PASSED — 46 tests |
| Signed archive | PASSED |
| IPA | PASSED — 1,977,467 bytes |
| IPA artifact | `MiBandNavigator-release-5` |
| IPA SHA-256 | `f662b14de8618e7296e86a32e726dcf9b9ae188e43e23ebeff44af07fce08497` |
| Signing method | Manual certificate and Ad Hoc provisioning profile |
| Google SDK entries | 0 |
| Physical iPhone tests | PENDING for this build |
| Mi Band symbols | Basic arrows retained; unsupported glyphs mapped to supported arrows with text labels |

## Automated verification completed

- XcodeGen generation, Swift 6 strict concurrency, simulator build, 46 XCTest cases, signed device archive, Ad Hoc IPA export, checksum, embedded profile, and code-signature structure all passed.
- MapKit search, route display, live location tracking, step classification, rerouting pipeline, notification thresholds, permissions, and settings persistence are covered by compilation or automated tests.
- Google Maps, Google Places, and Google Navigation dependencies were removed from the application and generated project.

## Physical verification remaining

- Install this MapKit IPA on the registered iPhone and verify live Apple Maps search/routing, background GPS, lock-screen notifications, Mi Fitness mirroring, and the five fallback maneuver cases on Mi Band 9.
- MapKit has no motorcycle transport mode; motorcycle requests intentionally use an automobile route and display that fallback in the UI.
