# IPA build

A `.ipa` is produced only by a signed `iOS Release` run.

1. Complete `GOOGLE_CLOUD_SETUP.md` and `APPLE_SIGNING.md`.
2. In GitHub Actions, run `iOS Release` with `signed = true`.
3. Choose the export method matching the provisioning profile:
   - `app-store-connect` for TestFlight/App Store upload.
   - `release-testing` for registered-device release testing.
   - `debugging` for registered-device development/debugging.
4. Download `MiBandNavigator-release-<run number>`.
5. Verify the `.ipa.sha256` file before retaining or transferring the IPA.

An App Store Connect IPA is intended for upload, not direct sideloading. An Ad Hoc/Release Testing IPA installs only on device UDIDs included in its profile.
