# Troubleshooting

## Map is blank

Confirm the key exists, billing is active, Maps/Navigation/Places APIs are enabled, and the iOS restriction matches the build Bundle ID.

## Route status says API key is unauthorized

Enable Navigation SDK for iOS in the same project as the key and verify API restrictions and Bundle ID restrictions.

## No Mi Band notification

Verify iOS notification permission, Mi Fitness notification access, Bluetooth connection, and app mirroring for MiMaps. Use Developer Tools to send a controlled test notification.

## Locked-screen guidance stops

Choose Always for location, enable notifications, keep Low Power Mode considerations in mind, and verify on a real iPhone. Review `docs/BACKGROUND_BEHAVIOR.md`.

## Signed release fails

Check that certificate/private key, profile, Bundle ID, team ID, export method, and profile type all match. Recreate expired assets. The exact `xcodebuild` message in Actions is authoritative.

## CI simulator cannot boot

Rerun once to rule out runner instability. If persistent, inspect `scripts/ci/simulator_udid.sh` output and the uploaded `.xcresult`.
