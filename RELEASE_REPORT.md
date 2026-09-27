# MiBand Navigator release report

Latest verified unsigned release workflow: [GitHub Actions run 36333160645](https://github.com/cuonqisme/MiMaps/actions/runs/36333160645).

| Field | Result |
|---|---|
| Application version | 0.1.0 |
| Build number | 2 |
| Verified source commit | `c55da5ce8d736fd6db49a139d28f89bf285f3b25` |
| Xcode | Xcode 26.6 (17F113) |
| Swift | Apple Swift 6.3.3 |
| macOS runner | 26.6.2 (`macos-26`) |
| iOS deployment target | 16.0 |
| Google Maps SDK | 11.2.0 |
| Google Navigation SDK | 11.2.0 |
| Google Places SDK | 11.1.0 |
| Simulator build | PASSED |
| Unit tests | PASSED — 52 tests |
| Release archive | PASSED — genuine unsigned `.xcarchive` |
| Release artifact | `MiBandNavigator-release-2` — 20,574,350 bytes, includes dSYM |
| IPA | NOT PRODUCED — Apple signing credentials unavailable |
| IPA artifact name | None |
| IPA SHA-256 | None |
| Signing method | Unsigned validation archive |
| TestFlight dry run | PASSED — tooling/tests/archive, run 36331078602 |
| TestFlight upload | NOT RUN — App Store Connect/signing credentials unavailable |
| Physical iPhone tests | PENDING |
| Mi Band symbols tested | NONE — physical Smart Band 9 test pending |
| Google navigation tests | SDK compiles; mapper/feed/pipeline unit-tested; real billed route not physically tested |

## Automated verification completed

- XcodeGen project generation, Swift 6 strict concurrency, Debug simulator build, 52 XCTest cases, Release device compilation, unsigned archive creation, dSYM inclusion, release reporting, artifact upload, and TestFlight upload-tool preflight.
- Mock navigation, threshold crossing/cooldown/deduplication, notification formatting/transport, permission preflight, two-wheeler fallback policy, Places view-model behavior, Google maneuver/feed mapping, reroute/arrival pipeline behavior, and configurable distance persistence are covered by automated tests.

## External blockers

A real signed IPA requires an Apple Developer membership, explicit App ID/App Store Connect record, Bundle ID, Team ID, Apple Distribution certificate with private key, matching provisioning profile, and the GitHub secrets listed in `APPLE_SIGNING.md`. A real TestFlight upload additionally requires the App Store Connect API credentials in `TESTFLIGHT.md`.

Google Maps tiles, Places network responses, live routing/GPS, background and lock-screen behavior, Mi Fitness mirroring, band vibration, Unicode rendering, latency, and road behavior require the user-supplied Google key and the physical checks in `HARDWARE_TESTING.md` and `docs/MIBAND_SYMBOL_TEST.md`.
