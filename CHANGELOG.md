# Changelog

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
- Added live maneuver, road, distance, ETA, reroute, and arrival feed mapping.
- Added notification threshold/cooldown/deduplication pipeline and mock navigation.
- Added background location lifecycle and contextual permission handling.
- Added simulator CI, release archive workflow, conditional signed IPA export, and release reporting.
- Added a guarded TestFlight workflow using App Store Connect API-key authentication and an independently runnable dry-run path.
- Added configurable notification distances, structured privacy-conscious logging, full navigation diagnostics, GPX simulator data, and physical-device test documentation.
