# Changelog

- Fixed nearby-category searches that surfaced `MKErrorDomain error 4`: a missing MapKit POI placemark now triggers Vietnamese/English keyword fallbacks across a wider nearby region, empty results no longer appear as technical errors, and the sheet provides retry actions.

Application/project rename in this release: MiMaps replaces the former product name across the user interface, Xcode project, schemes, test module, archives, and distribution artifacts. The provisioned bundle identifier is retained for install compatibility.

## 0.1.0 — in development

- Added an opt-in, guarded Band 8 full-screen navigation pipeline: native 192×490 rendering, RGB565/RLE watchface packaging, type-16 transfer, install/activate commands, active-face capture, restoration, MiMaps-only cleanup, progress diagnostics, update coalescing, and automatic restore when navigation stops. The normal notification path remains the default until physical firmware testing succeeds.
- Assigned a fresh session notification ID whenever the Band navigation package changes, preventing firmware from treating a new icon package as an update to the legacy fixed notification slot and skipping the package-query handshake.
- Rotated the navigation icon cache key to `p4` and stopped claiming that an icon is cached when the Band never sends a package query; the primer notification is no longer duplicated on this fallback path.
- Corrected the Band 8 icon handshake to start with a notification for a short revisioned package key, wait for the Band's package query and icon request, and only then open the type-50 upload; forced uploads without a device request now fail fast instead of waiting repeatedly.
- Coalesced realtime/test updates while picture mode is negotiating so only the newest instruction is resent after icon upload.
- Fixed Band 8 icon transfer on iOS by using MTU-sized `writeWithoutResponse` frames on FE95/0055 instead of unsupported ATT long writes, with CoreBluetooth backpressure and Band-requested missing-frame retransmission.
- Reduced the opt-in direct-Bluetooth live-distance interval from five seconds to two seconds; updates continue to replace one stable navigation card.
- Added an opt-in direct-Bluetooth live-distance mode that updates one reusable Band navigation card without creating extra iPhone notifications.
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
