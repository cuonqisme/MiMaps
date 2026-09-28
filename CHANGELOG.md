# Changelog

- Fixed nearby-category searches that surfaced `MKErrorDomain error 4`: a missing MapKit POI placemark now triggers Vietnamese/English keyword fallbacks across a wider nearby region, empty results no longer appear as technical errors, and the sheet provides retry actions.

Application/project rename in this release: MiMaps replaces the former product name across the user interface, Xcode project, schemes, test module, archives, and distribution artifacts. The provisioned bundle identifier is retained for install compatibility.

## 0.1.0 — in development

- Replaced the previous Google SDK integration with native Apple MapKit search, route preview, active guidance, and rerouting.
- Added standard, muted, satellite, and hybrid map styles plus an unobstructed recenter control.
- Added car, walking, transit, and motorcycle-request modes with an explicit automobile fallback when motorcycle is selected.
- Added alternative-route cards with ETA, distance, route advantages/disadvantages, toll and highway information.
- Added avoid-toll and avoid-highway route preferences.
- Added nearby place categories, tappable Apple map POIs, tappable nearby pins, and long-press location pinning.
- Added Google Maps clipboard-link import with short-link resolution and location-biased Apple place search.
- Added professional iPhone maneuver icons and Mi Band-safe Unicode fallbacks with explicit text for sharp turns, U-turns, and roundabouts.
- Added live GPS speed display and provider-neutral speed-limit/safety-camera alert notification support.
- Fixed route overlays remaining visible after stopping navigation.
- Prevented route-preview instructions from sending Mi Band notifications before navigation starts.
- Fixed mock pause/resume and speed controls in SwiftUI forms and reduced the default simulation speed.
- Replaced nearby free-text queries with MapKit point-of-interest category filters and explicit location-permission/GPS handling.
- Redesigned destination search with a persistent modern search field, richer result cards, empty/error states, and a clearer Google Maps link importer.
- Added locally stored recent destinations and a live Apple Maps traffic overlay toggle.
- Added a draggable, distance-sorted nearby-place result sheet with route, call, website, and share actions.
- Replaced the obscured native compass with an accessible map heading-reset control positioned below the search and quick-category controls.
- Documented the verified Sygic iOS safety-alert capabilities and the license/coverage checks required before integration; motorcycle routing remains an explicit MapKit automobile fallback.
- Added live maneuver, road, distance, ETA, reroute, and arrival feed mapping.
- Added notification threshold/cooldown/deduplication pipeline and mock navigation.
- Added background location lifecycle and contextual permission handling.
- Added simulator CI, release archive workflow, conditional signed IPA export, and release reporting.
- Added a guarded TestFlight workflow using App Store Connect API-key authentication and an independently runnable dry-run path.
- Added configurable notification distances, structured privacy-conscious logging, full navigation diagnostics, GPX simulator data, and physical-device test documentation.
