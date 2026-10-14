# Snap Journal — architecture starter

## Components

- **SnapJournal (iOS app)**: SwiftUI UI, session lifecycle, journal storage. The only code we write.
- **DAT SDK** (`MWDATCore`, `MWDATCamera` via SwiftPM): registration, device discovery, session, camera stream + photo capture.
- **Meta AI app**: runs the registration and camera-permission flows via deeplink; lists our app under App Connections.
- **Glasses (Gen 2)**: Meta firmware; exposes camera/mic/speaker over Bluetooth during our session. One session at a time.

## Happy-path flow

1. "Connect glasses" → `Wearables.configure()` → registration deeplink → Meta AI confirms → back to app.
2. "Start session" → create session → `session.start()` → add camera → stream starts.
3. "Snap" → capture a photo during the active stream → JPEG delivered to the app → saved with a timestamp.
4. Session pauses/stops via the app, or via the glasses (tap / take off / close hinges).

Key constraint: **photo capture only works during an active camera stream** — the stream must be running before a snap.

## Decisions for system design

1. Storage: local-only (Documents directory) vs iCloud sync? Start local.
2. Session UX: one long-lived stream while journaling, or start/stop per snap? (Battery vs latency tradeoff.)
3. Captions: manual note field now; auto-caption via model later?
4. Resilience: hinge-close / take-off kills the session — auto-reconnect policy?
5. Background: keep the session alive when the app backgrounds? (DAT supports it; adds complexity.)

## Non-goals for slice 1

No server streaming, no AI captions, no complications widget. Prove: register → session → snap → saved photo.
