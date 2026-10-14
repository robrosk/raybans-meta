# Setup

Based on Meta's DAT docs (Sep 2026). Do these once:

1. **Apple side**: registered bundle identifier for the app; Xcode 14+, iOS 15.2+ deployment target.
2. **Meta side**: Wearables Developer Center org (we have `rr-metas`). Create a project for SnapJournal and put the issued **MetaAppID**, **ClientToken**, **TeamID**, and **AppLinkURLScheme** in `Info.plist`. The URL scheme lets the Meta AI app call back into our app during registration.
3. **Glasses**: Ray-Ban Meta paired in the Meta AI app (Developer Mode as needed). No hardware handy? Use the **Mock Device Kit** — it simulates pairing, camera, permissions, and device state.
4. **Permissions**: camera permission is granted through the Meta AI app (allow once / allow always); mic goes through the iOS Bluetooth/HFP system dialogs.
5. **Distribution**: App Store publishing is *not currently supported* — the SDK uses the `ExternalAccessory` framework, which triggers App Store rejection. Share test builds via Meta's release channels instead.

Then follow `ios/README.md`, resolve the SwiftPM dependency in Xcode, and run on a real device (Bluetooth required — the simulator can't do this part).
