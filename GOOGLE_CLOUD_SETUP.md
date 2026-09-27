# Google Cloud setup

1. Create or select a Google Cloud project and attach an active billing account.
2. Enable **Maps SDK for iOS**, **Navigation SDK for iOS**, and **Places API (New) / Places SDK for iOS** as required by the current Google console.
3. Create one API key for the iOS application.
4. Add an iOS application restriction using the exact release Bundle ID.
5. Restrict the key to the enabled Maps Platform APIs instead of leaving it unrestricted.
6. Copy `Configuration/Secrets.example.xcconfig` to `Configuration/Secrets.xcconfig` for a local Mac build and replace the placeholder.
7. Add the same value as the `GOOGLE_MAPS_API_KEY` GitHub Actions secret.

The secret file is ignored by Git. Never commit the key. Simulator unit tests pass without a key; map tiles, Places results, route calculation, and real navigation require a valid billed project and authorized key.

Validate on a physical iPhone: map tiles appear, autocomplete returns results, a route can be calculated, Navigation terms appear when needed, and guidance begins. Review Google Maps Platform pricing, quotas, budgets, and alerts before road testing.
