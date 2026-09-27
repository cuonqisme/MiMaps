# GitHub Actions setup

`iOS CI` runs on every push to `main`/`develop` and every pull request. It generates the Xcode project, builds the Debug configuration, runs all tests, and uploads the `.xcresult` bundle.

`iOS Release` is manual. Open **Actions → iOS Release → Run workflow**:

- `signed = false`: tests and creates an unsigned Release archive. This validates compilation but cannot be installed.
- `signed = true`: requires every signing secret from `APPLE_SIGNING.md`, creates a signed archive, exports an IPA, computes SHA-256, and uploads artifacts.

The GitHub run number becomes `CFBundleVersion`, ensuring increasing TestFlight build numbers. Artifacts are retained for 14 days. Secrets and signing files are never uploaded.
