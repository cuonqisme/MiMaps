# Background and lock-screen behavior

MiMaps enables iOS background location mode only for an active guidance session. When guidance starts, it enables `allowsBackgroundLocationUpdates` and starts Core Location updates used by the MapKit navigation provider. It stops updates immediately when guidance stops or arrives.

MiMaps local notifications remain the single wearable output path, so all alerts pass through the app's threshold, cooldown, and deduplication policy.

## Permissions

- Route preview requires Location While Using the App.
- Starting guidance contextually requests the Always upgrade for reliable locked-screen guidance.
- If the user keeps While Using, foreground navigation remains available and iOS may continue an already-active session in the background, but the UI warns that locked-screen reliability is reduced.
- Notification permission is requested only when the user starts guidance with Mi Band notifications enabled.
- Denied permissions never block map browsing. Location denial blocks guidance; notification denial only disables wearable alerts.

## Energy and privacy

- Location updates never start at app launch or during route preview.
- Updates stop at arrival and explicit STOP.
- The app stores no coordinate history and sends no location to an app-owned backend.
- Developer diagnostics expose only the timestamp of the latest location update.
- Apple MapKit and Core Location use their documented system and network services.

Background execution, lock-screen delivery, Mi Fitness mirroring, latency, and battery drain must be verified on a real iPhone. Simulator CI verifies configuration, compilation, permission policy, and non-location business logic only.
