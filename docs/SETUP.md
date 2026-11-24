# Setup

Based on Meta's DAT docs and SDK 1.1.0 (Nov 2026). Do these once:

1. **Apple side**: registered bundle identifier for the app; Xcode 26.4+, iOS 17.2+ deployment target (the DAT SDK's minimums, per Meta's getting-started guide and CameraAccess sample).
2. **Meta side**: Wearables Developer Center org (we have `rr-metas`). Create a project for SnapJournal. In `Info.plist`, add a **`MWDAT` dictionary** (this nesting matters — verified against Meta's CameraAccess sample) with:
   - `AppLinkURLScheme` — your URL scheme (e.g. `snapjournal://`), so the Meta AI app can call back into our app during registration
   - `MetaAppID` — from the Developer Center project (or `$(META_APP_ID)`)
   - `ClientToken` — from the Developer Center project (or `$(CLIENT_TOKEN)`)
   - `TeamID` — your Apple Developer Team ID (or `$(DEVELOPMENT_TEAM)`)
   
   Also required (same sample): `NSBluetoothAlwaysUsageDescription` + `NSBluetoothPeripheralUsageDescription` ("Needed to connect to Meta AI Glasses"), `NSLocalNetworkUsageDescription` + `NSBonjourServices` (`_bonjour._tcp`, for glasses discovery over Wi-Fi), `NSMicrophoneUsageDescription`, and `UIBackgroundModes` including `bluetooth-central`, `bluetooth-peripheral`, `audio`.

   Also add a `CFBundleURLTypes` entry whose scheme matches `AppLinkURLScheme` (e.g. `snapjournal`); without it the Meta AI app cannot call back. Meta's getting-started guide also lists the `external-accessory` background mode and `UISupportedExternalAccessoryProtocols` = `com.meta.ar.wearable`, which camera streaming over Bluetooth Classic needs.
3. **Glasses**: Ray-Ban Meta paired in the Meta AI app (Developer Mode as needed). No hardware handy? Use the **Mock Device Kit** — it simulates pairing, camera, permissions, and device state.
4. **Permissions**: camera permission is granted through the Meta AI app (allow once / allow always); mic goes through the iOS Bluetooth/HFP system dialogs.
5. **Distribution**: App Store publishing is *not currently supported* — the SDK uses the `ExternalAccessory` framework, which triggers App Store rejection. Share test builds via Meta's release channels instead.

Then follow `platform/ios/README.md`, resolve the SwiftPM dependency in Xcode, and run on a real device (Bluetooth required — the simulator can't do this part).
