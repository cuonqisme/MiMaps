# Privacy

MiMaps uses device location only to calculate and follow an active navigation route. It does not store coordinate history, create user profiles, include analytics, or transmit location to an application-owned backend.

Apple MapKit communicates with Apple to search for places and calculate routes under Apple's terms and privacy policy. iOS local notifications contain the upcoming maneuver, distance, and road name so iOS/Mi Fitness can mirror them to the paired band.

Background location updates start only after the user starts guidance and stop on arrival or STOP. Permission status can be reviewed in the app and changed in iOS Settings. See `docs/BACKGROUND_BEHAVIOR.md` for operational details.

The debug screen keeps only the latest location snapshot in memory while guidance is active and clears it on stop or arrival. Structured production logs report state and errors without logging coordinates or a route history.

The application privacy manifest declares its use of app-scoped `UserDefaults` for user preferences (`CA92.1`).
