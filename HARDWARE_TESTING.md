# Physical iPhone and Xiaomi Smart Band 9 testing

These checks require a real iPhone, Xiaomi Smart Band 9, Mi Fitness, a valid Google Maps Platform key, and an installable signed build. CI cannot verify them.

## Prepare the devices

1. Install Mi Fitness from the App Store and pair the Smart Band 9.
2. Confirm Bluetooth is connected and the band has sufficient charge.
3. Install the signed MiMaps build through TestFlight or an Ad Hoc/development profile.
4. On iPhone, allow MiMaps notifications and location access. Choose **Always** only if lock-screen/background navigation is being tested.
5. In Mi Fitness, enable iPhone app-notification mirroring for MiMaps. Menu names vary by Mi Fitness version/region.
6. Leave phone-notification sound off initially; MiMaps does not control the band's vibration pattern.

## Symbol and notification test

Open **Công cụ → Test Mi Band Notifications**. Set the road to `Trần Phú`, test 30 m, 80 m, 200 m, 500 m, 1 km, and 2 km, then test:

- ↑ Straight
- ↖ Slight Left
- ← Left
- ↰ Sharp Left
- ↗ Slight Right
- → Right
- ↱ Sharp Right
- ↶ U-Turn Left
- ↷ U-Turn Right
- ⟳ Roundabout
- ● Destination

For every symbol, record whether the band vibrates, the arrow and distance are legible, Vietnamese accents render, the street name fits, and any glyph is replaced by a box. Use **GỬI TẤT CẢ BIỂU TƯỢNG TUẦN TỰ** only while stationary; notifications are spaced by three seconds. Record results in `docs/MIBAND_SYMBOL_TEST.md` without marking untested rows as passed.

Measure approximate latency from tapping send to band display. Repeat with the phone screen locked and the app foregrounded/backgrounded.

## Safe road-test checklist

Use a passenger as operator or stop safely before touching the phone. Do not interact with the phone or band while driving.

- Map tiles and Google attribution are visible.
- Places autocomplete returns a real destination.
- Motorcycle routing is requested; any driving fallback is visibly reported.
- Route preview appears and guidance starts.
- GPS follows the route and the current road/maneuver update.
- One alert occurs when crossing each configured 500/200/80/30 m threshold; no update spam occurs between thresholds.
- Completing a turn loads the next maneuver and resets threshold state.
- A safe deliberate deviation causes rerouting and subsequent instructions continue.
- Arrival produces one destination notification.
- STOP immediately ends guidance and background location updates.
- Locked-screen/background notifications continue within iOS limits.
- Record notification latency and any battery/thermal issue over a representative trip.

## Evidence to retain

Record app version/build, iPhone model and iOS version, Mi Fitness version, band firmware, test date, permission state, route region, symbol matrix, approximate latency, background result, and defects. Do not publish precise personal route/location history in logs or issues.
