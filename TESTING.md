# Testing

`scripts/ci/test.sh` boots an available iPhone simulator and executes the entire XCTest target with warnings treated as errors. The result bundle is written to `test-results/MiBandNavigator.xcresult` and uploaded by CI.

Covered automation includes domain formatting, thresholds and cooldown, deduplication, notification transport, mock navigation, Places view-model behavior, Google maneuver mapping, live-feed conversion, provider-to-notification integration, permission preflight, and nonfatal wearable-delivery failures.

Google billing/network behavior, GPS, background execution, Mi Fitness, and Xiaomi Smart Band behavior require a physical iPhone and band. CI must not be interpreted as hardware verification.

## GPX simulator route

`TestRoutes/sample_city_route.gpx` contains a synthetic Hanoi track for later Xcode simulator checks. On a Mac, run the app in an iPhone simulator, choose **Features → Location → GPX File…** (wording can vary by Xcode version), and select the file. GPX playback validates UI/location flow only; it does not validate Google billing, real GPS, background reliability, Mi Fitness, or band rendering.

Use `HARDWARE_TESTING.md` for physical notification and road testing.
