# Sygic Maps SDK evaluation

Evaluation date: 2026-09-28

## Confirmed capabilities

Sygic's public iOS Maps SDK documentation exposes navigation callbacks and settings for:

- current speed-limit updates;
- speed-limit warnings;
- fixed and community-reported speed-camera warnings;
- traffic and road incidents;
- railway-crossing and sharp-curve warnings;
- spoken navigation and warning audio.

These capabilities could feed the existing provider-neutral `SafetyAlert` and notification pipeline, so the phone and Mi Band can receive concise alerts without inventing data.

Primary references:

- [Sygic iOS navigation guide](https://developers.sygic.com/maps-sdk/ios/navigation/)
- [Sygic iOS API reference](https://developers.sygic.com/maps-sdk/api-reference/ios/28.2/)
- [Sygic Maps & Navigation SDK for developers](https://enterprise.sygic.com/maps-navigation-sdk-developers)
- [Sygic SDK safety features](https://enterprise.sygic.com/professional-gps-navigation-sdk/safety)

## Motorcycle routing status

The consumer Sygic application offering a motorcycle mode does not prove that the same mode is included in every Maps SDK license. The public iOS routing guide documents car and pedestrian routing and a generic vehicle-profile API, but it does not publicly document a motorcycle route type or guarantee motorcycle coverage in Vietnam.

MiBand Navigator must therefore continue to label its current motorcycle option as an automobile fallback. It must not silently present a car route as a motorcycle route.

Primary references:

- [Sygic iOS routing guide](https://developers.sygic.com/maps-sdk/ios/routing/)
- [SYRoutingOptions API](https://developers.sygic.com/maps-sdk/api-reference/ios/28.2/da/d56/interfaceSYRoutingOptions.html)
- [SYVehicleProfile API](https://developers.sygic.com/maps-sdk/api-reference/ios/28.2/d8/dbe/interfaceSYVehicleProfile.html)

## Inputs required before integration

Implementation can start after all of the following are available:

1. The official Sygic Maps SDK iOS package and a commercial license/API key for this bundle ID.
2. Written confirmation or account documentation that the licensed iOS SDK exposes motorcycle routing in Vietnam.
3. Confirmation that speed-camera, speed-limit, incident, and community-report data are licensed for display and notification in Vietnam.
4. The applicable SDK distribution terms, offline-map entitlement, and production quota.

Secrets must be injected through the ignored local secrets configuration or GitHub Actions secrets. They must never be committed.

## Proposed integration boundary

When the requirements above are met, add `SygicNavigationProvider` behind the existing navigation-provider interface and map Sygic events into the current route, maneuver, speed-limit, and `SafetyAlert` models. Keep MapKit as a selectable fallback. This preserves the tested notification and Mi Band behavior while allowing provider-specific map, traffic, camera, and motorcycle capabilities.
