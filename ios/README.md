# ios/

SnapJournal iOS app. The Xcode project itself is created in Xcode (not scaffolded here):

1. New iOS App project named `SnapJournal`, using your registered bundle ID, iOS 15.2+.
2. File > Add Package Dependencies > `https://github.com/facebook/meta-wearables-dat-ios`
3. Add `Info.plist` keys from your Developer Center project: `AppLinkURLScheme`, `MetaAppID`, `ClientToken`, `TeamID`.
4. Add the files in `Sources/` to the app target.
5. When in doubt, compare against the official sample app: `facebook/meta-wearables-dat-ios/tree/main/samples`.

Run on a real device — Bluetooth session with the glasses doesn't work in the simulator.
