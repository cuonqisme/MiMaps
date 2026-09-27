# TestFlight

The manual `TestFlight` workflow has two modes:

- `upload = false` runs all tests, confirms Apple's `altool` is present, and creates an unsigned Release archive. It makes no external upload.
- `upload = true` creates a signed App Store archive and IPA, validates it, and uploads it to App Store Connect. Set `confirmation` to exactly `UPLOAD`.

Apple currently supports build upload through Xcode, Transporter, and `xcrun altool`. This repository uses `altool` with an App Store Connect API key, avoiding Apple ID passwords in CI.

## One-time App Store Connect setup

1. Join the Apple Developer Program and accept all current agreements.
2. Create the explicit App ID, App Store Connect app record, Apple Distribution certificate, and App Store provisioning profile described in `APPLE_SIGNING.md`.
3. In **Users and Access → Integrations → App Store Connect API**, create a team API key with the minimum role that can upload builds (Developer or App Manager as appropriate).
4. Download `AuthKey_<KEY_ID>.p8` immediately; Apple only allows one download.
5. Add these GitHub Actions secrets:

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer UUID |
| `ASC_PRIVATE_KEY_BASE64` | Base64 of the downloaded `.p8` file |

PowerShell command for the private-key secret:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('AuthKey_KEYID.p8')) | Set-Clipboard
```

## Upload

Open **Actions → TestFlight → Run workflow**, select `upload = true`, and enter `UPLOAD`. The GitHub run number is injected as `CFBundleVersion`, so each workflow run receives a unique increasing build number.

Success means App Store Connect accepted the binary for processing. Processing, export-compliance questions, beta review, tester groups, and installation remain visible actions in App Store Connect/TestFlight. Never treat a dry run as an upload.

The API private key is written only to Apple's documented private-key lookup directory for the duration of the upload and is removed by the script's exit trap.
