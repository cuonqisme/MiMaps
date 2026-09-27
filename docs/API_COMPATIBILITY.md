# API compatibility

Verified against official vendor documentation on 2026-09-27.

| Area | Selected baseline | Notes |
|---|---|---|
| Apple toolchain | Xcode 26.6, Swift 6.2 | App Store Connect requires Xcode 26+ and an iOS 26 SDK from 2026-04-28. |
| Deployment target | iOS 16.0 | Current Google Maps Platform iOS SDKs require iOS 16. |
| GitHub runner | `macos-26` | Explicit runner; Xcode 26.6 is selected with `DEVELOPER_DIR`. |
| Navigation SDK | 11.2.0 | Package URL is `https://github.com/googlemaps/ios-navigation-sdk`; product is `GoogleNavigation`. Requires Xcode 26, iOS 16, and a motion usage description. |
| Maps SDK | 11.2.0 | Package URL is `https://github.com/googlemaps/ios-maps-sdk`; product is `GoogleMaps`. |
| Places Swift SDK | 11.1.0 | Latest stable package listed at verification time. Package URL is `https://github.com/googlemaps/ios-places-sdk`; product is `GooglePlacesSwift`. |

Google integration uses Swift Package Manager only and will pin exact versions. SDK types are isolated behind provider/service adapters. Simulator unit tests do not require an API key.

Route calculation requests two-wheeler mode for motorcycle navigation. It falls back to driving only when Navigation SDK explicitly returns `travelModeUnsupported`; all other route failures are surfaced to the user.

The wearable data feed uses `GMSNavigatorListener.navigator(_:didUpdate:)` with `GMSNavigationNavInfo`. It maps `currentStep`, `distanceToCurrentStepMeters`, `distanceToFinalDestinationMeters`, `timeToFinalDestinationSeconds`, arrival callbacks, and navigation state into provider-neutral models. Current SDK listeners are registered with `add(_:)`/`remove(_:)`; the retired delegate API is not used.

## Official references

- Apple Xcode 26 release notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes
- Apple upload requirements: https://developer.apple.com/news/upcoming-requirements/
- GitHub macOS 26 image: https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md
- Navigation SDK overview: https://developers.google.com/maps/documentation/navigation/ios-sdk/setup-overview
- Navigation SDK release notes: https://developers.google.com/maps/documentation/navigation/ios-sdk/release-notes
- Places SDK setup: https://developers.google.com/maps/documentation/places/ios-sdk/config
