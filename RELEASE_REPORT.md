# MiMaps release report

Latest verified signed release workflow: [GitHub Actions run 36365845588](https://github.com/cuonqisme/MiMaps/actions/runs/36365845588).

| Field | Result |
|---|---|
| Application version | 0.1.0 |
| Build number | 10 |
| Verified source commit | `4d8dff54062def56cf84ee49fbcb91af49a11059` |
| Xcode | Xcode 26.6 (17F113) |
| Swift | Apple Swift 6.3.3 |
| macOS runner | 26.6.2 (`macos-26`) |
| iOS deployment target | 16.0 |
| Product / app bundle | `MiMaps` / `MiMaps.app` |
| Map provider | Apple MapKit (native) |
| Third-party map API key | Not required |
| Simulator build | PASSED |
| Unit tests | PASSED — 56 tests |
| Signed archive | PASSED |
| IPA | PASSED — 2,103,603 bytes |
| IPA artifact | `MiMaps-release-10` |
| IPA SHA-256 | `2d50ccffaf7bed8f5f0961e722d60a685482433086cd45f14f016625ef14e511` |
| Signing method | Manual certificate and Ad Hoc provisioning profile |
| Embedded provisioning profile | PRESENT |
| Code signature resources | PRESENT |
| Google SDK entries | 0 |
| Physical iPhone tests | PENDING for this build |
| Mi Band symbols | Basic arrows retained; unsupported glyphs mapped to supported arrows with text labels |

## Automated verification completed

- XcodeGen generation, Swift 6 strict concurrency, simulator build, 56 XCTest cases, signed device archive, Ad Hoc IPA export, checksum, embedded profile, and code-signature structure all passed.
- The application, product, module, Xcode project, scheme, test target, archive, exported IPA, and GitHub artifact were renamed to MiMaps. The provisioned bundle identifier remains unchanged so the existing profile can sign and install the app.
- The release includes the distance-sorted nearby result sheet with route/call/website/share actions, the unobstructed heading-reset control, and Vietnamese/English keyword fallbacks when MapKit returns `placemarkNotFound` for a structured POI request.
- Route cleanup, preview-notification suppression, mock controls, category-filtered nearby POIs, recent destinations, traffic, map styles, pin selection, alternate routes, route preferences, live location tracking, rerouting, Google Maps link parsing, safety-alert formatting, notification thresholds, permissions, and settings persistence are covered by compilation or automated tests.
- Google Maps, Google Places, and Google Navigation dependencies are absent from the generated project.

## Physical verification remaining

- Install `artifacts/MiMaps-NearbySearchFix.ipa` on the registered iPhone and verify fuel/food/parking/hospital quick searches, retry and empty states, place actions, heading reset, live routing, background GPS, lock-screen notifications, Mi Fitness mirroring, and Mi Band symbols.
- MapKit has no motorcycle transport mode; motorcycle requests intentionally use an automobile route and display that fallback in the UI.
- MapKit does not provide camera/speed-limit data or an avoid-overpass preference. The Sygic SDK can supply safety alerts after its commercial license/key and Vietnam motorcycle/safety-data entitlement are provided and confirmed.
- Direct Google Maps Share Sheet integration requires a separately provisioned Share Extension bundle ID/profile. This build supports Google Maps copy-link import but intentionally contains no unsigned extension.
