# platform/ios/

iOS app: SwiftUI (Views) + ViewModels (MVVM) + Objective-C++ bridge +
Swift adapters, over the portable C++ core in `core/`.

## Xcode setup

1. Create a new iOS App project in this directory (name it `SnapJournal`,
   iOS 15.2+, using your registered bundle ID).
2. Add the C++ core: drag `core/include` and `core/src` into the project
   (or add them to the target's Compile Sources / Header Search Paths).
3. Add `Bridge/RBSessionBridge.h` + `RBSessionBridge.mm` to the target.
   Xcode will prompt to create a bridging header — accept it, then
   `#import "RBSessionBridge.h"` there.
4. Add `Adapters/` and `App/` Swift files to the target.
5. File > Add Package Dependencies >
   `https://github.com/facebook/meta-wearables-dat-ios` (needed for the real
   `DAT*` adapters; the `FakeCameraAdapter` works without it).
6. Add the `MWDAT` dictionary + required keys to `Info.plist` — see
   `docs/SETUP.md` for the exact nesting and the Bluetooth/mic/background
   entries Meta's sample requires.
7. Compare against the official sample app when wiring adapters:
   `facebook/meta-wearables-dat-ios/tree/main/samples/CameraAccess`.
   Without glasses, enable the SDK's Mock Device Kit (`MWDATMockDevice`,
   `MockDeviceKit.shared`) — the sample shows the pattern.

## Notes

- `RBSessionBridge` retains attached adapters, so one-line
  `bridge.attachCameraInput(...)` calls are safe.
- `DATCameraAdapter` is fully wired to the real SDK (session -> camera ->
  stream -> photo). `HFPMicrophoneAdapter` covers the happy path;
  interruption/route-change handling (see the sample's
  `AudioInputHandler.swift`) is still TODO. `DATDeviceStateAdapter` is a
  precise TODO against `MWDATCore`'s device APIs.

Run on a real device — the Bluetooth session with the glasses doesn't work
in the simulator. The `FakeCameraAdapter` lets all UI work proceed without
hardware.

## Where things live

- `Bridge/` — the only place Swift meets C++. Keep it mechanical:
  forward calls down, marshal callbacks to main, convert types.
- `Adapters/` — one per input. Each conforms to an `RB*` protocol and pushes
  results through `RBInputSink`. Real and fake adapters are interchangeable.
- `App/ViewModels/` — one `ObservableObject` per input stream. No UIKit,
  no SDK imports, no threading code.
- `App/Views/` — SwiftUI. Observes ViewModels, nothing else.
