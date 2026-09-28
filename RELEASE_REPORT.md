# MiMaps release report

Latest verified signed release workflow: [GitHub Actions run 36362994045](https://github.com/cuonqisme/MiMaps/actions/runs/36362994045).

| Field | Result |
|---|---|
| Application version | 0.1.0 |
| Build number | 9 |
| Verified source commit | `4f34356967b0282e194a53440ac7433e14656937` |
| Xcode | Xcode 26.6 (17F113) |
| Swift | Apple Swift 6.3.3 |
| macOS runner | 26.6.2 (`macos-26`) |
| iOS deployment target | 16.0 |
| Product / app bundle | `MiMaps` / `MiMaps.app` |
| Map provider | Apple MapKit (native) |
| Third-party map API key | Not required |
| Simulator build | PASSED |
| Unit tests | PASSED — 54 tests |
| Signed archive | PASSED |
| IPA | PASSED — 2,099,461 bytes |
| IPA artifact | `MiMaps-release-9` |
| IPA SHA-256 | `74eab1bdabbfc3d0d2eef96b52957a036f878a08852044c052fd83666afa90fb` |
| Signing method | Manual certificate and Ad Hoc provisioning profile |
| Embedded provisioning profile | PRESENT |
| Code signature resources | PRESENT |
| Google SDK entries | 0 |
| Physical iPhone tests | PENDING for this build |
| Mi Band symbols | Basic arrows retained; unsupported glyphs mapped to supported arrows with text labels |

## Automated verification completed

- XcodeGen generation, Swift 6 strict concurrency, simulator build, 54 XCTest cases, signed device archive, Ad Hoc IPA export, checksum, embedded profile, and code-signature structure all passed.
- The application, product, module, Xcode project, scheme, test target, archive, exported IPA, and GitHub artifact were renamed to MiMaps. The provisioned bundle identifier remains unchanged so the existing profile can sign and install the app.
- The release includes the distance-sorted nearby result sheet with route/call/website/share actions and the unobstructed heading-reset control.
- Route cleanup, preview-notification suppression, mock controls, category-filtered nearby POIs, recent destinations, traffic, map styles, pin selection, alternate routes, route preferences, live location tracking, rerouting, Google Maps link parsing, safety-alert formatting, notification thresholds, permissions, and settings persistence are covered by compilation or automated tests.
- Google Maps, Google Places, and Google Navigation dependencies are absent from the generated project.

## Physical verification remaining

- Install `artifacts/MiMaps-NearbyPlaces.ipa` on the registered iPhone and verify the MiMaps home-screen label, nearby sheet, place actions, heading reset, live routing, background GPS, lock-screen notifications, Mi Fitness mirroring, and Mi Band symbols.
- MapKit has no motorcycle transport mode; motorcycle requests intentionally use an automobile route and display that fallback in the UI.
- MapKit does not provide camera/speed-limit data or an avoid-overpass preference. The Sygic SDK can supply safety alerts after its commercial license/key and Vietnam motorcycle/safety-data entitlement are provided and confirmed.
- Direct Google Maps Share Sheet integration requires a separately provisioned Share Extension bundle ID/profile. This build supports Google Maps copy-link import but intentionally contains no unsigned extension.
