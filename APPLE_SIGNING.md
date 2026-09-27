# Apple signing setup

Signed distribution requires an active Apple Developer Program membership. Never provide an Apple password to CI.

## Create Apple resources

1. Create an explicit App ID in Certificates, Identifiers & Profiles.
2. Use the same reverse-DNS Bundle ID for the App ID, App Store Connect app record, and `BUNDLE_ID` GitHub secret.
3. Enable the required app capability for background location updates in the identifier/profile.
4. Create an Apple Distribution certificate and export it with its private key as a password-protected `.p12`.
5. Create a provisioning profile matching the intended export method:
   - App Store profile for `app-store-connect` and TestFlight.
   - Ad Hoc profile for `release-testing`; register the target iPhone UDID first.
   - Development profile for `debugging`.
6. Download the `.mobileprovision` file.

## GitHub Actions secrets

Configure these in repository **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | 10-character Apple team identifier |
| `BUNDLE_ID` | Explicit application bundle identifier |
| `BUILD_CERTIFICATE_BASE64` | Base64 of the `.p12` file |
| `P12_PASSWORD` | Password used when exporting the `.p12` |
| `PROVISIONING_PROFILE_BASE64` | Base64 of the `.mobileprovision` file |
| `KEYCHAIN_PASSWORD` | Random CI-only password for the temporary keychain |
| `GOOGLE_MAPS_API_KEY` | iOS-restricted Google Maps Platform key |

TestFlight additionally requires `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_PRIVATE_KEY_BASE64`; see `TESTFLIGHT.md`. The App Store Connect API key is separate from the signing certificate and provisioning profile.

On PowerShell, create base64 values without line wrapping:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('AppleDistribution.p12')) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes('MiBandNavigator.mobileprovision')) | Set-Clipboard
```

The release workflow creates a temporary keychain, imports the certificate and profile, extracts the profile name, builds, then deletes the temporary signing assets in an `always()` cleanup step.
