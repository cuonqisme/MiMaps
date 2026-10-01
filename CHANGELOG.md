# Changelog

- Fixed nearby-category searches that surfaced `MKErrorDomain error 4`: a missing MapKit POI placemark now triggers Vietnamese/English keyword fallbacks across a wider nearby region, empty results no longer appear as technical errors, and the sheet provides retry actions.

Application/project rename in this release: MiMaps replaces the former product name across the user interface, Xcode project, schemes, test module, archives, and distribution artifacts. The provisioned bundle identifier is retained for install compatibility.

## 0.1.0 — in development

- Fixed Band 8 icon transfer on iOS by using MTU-sized `writeWithoutResponse` frames on FE95/0055 instead of unsupported ATT long writes, with CoreBluetooth backpressure and Band-requested missing-frame retransmission.
- Reduced the opt-in direct-Bluetooth live-distance interval from five seconds to two seconds; updates continue to replace one stable navigation card.
- Added a Band 8 picture-mode recovery path for firmware that ACKs navigation notifications but does not request an application icon: MiMaps now primes the package context, attempts the device-observed 28x28/BGRA icon upload, and falls back to text with explicit diagnostics if the upload is rejected.
- Added an opt-in direct-Bluetooth live-distance mode that updates one reusable Band navigation card at most every five seconds, without creating extra iPhone notifications.
- Restored the firmware-accepted `com.mimaps` notification package after physical Band 8 testing showed that per-maneuver package aliases were ACKed but not rendered.
- Distinguished a Bluetooth transport ACK from confirmed on-screen delivery in Band Lab diagnostics.
- Added explicit on-device runtime detection: standard Band 8 uses picture mode/watchfaces and must not be sent Vela RPK packages; Band 8 Pro and Band 9/10 follow Xiaomi's separately signed RPK workflow.

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
