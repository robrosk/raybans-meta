# SnapJournal design

Status: describes the code as of `562d936`. The decisions marked **Decided**
(D-4 to D-10) land in the pull requests that implement them, and each of those
updates this doc. `docs/ARCHITECTURE.md` is the short
overview; this doc is the rationale and the contract. When they disagree about
behavior, the contract here wins and the code or the overview is the bug.

## What the system does

An iPhone app talks to Ray-Ban Meta glasses through Meta's Wearables Device
Access Toolkit (DAT). Nothing runs on the glasses. The first slice is a snap
journal: register with Meta AI, open a session, capture a photo mid-stream,
keep it with a timestamp. The same session also carries the glasses mic (over
Bluetooth HFP) and device state (battery, hinge, wear, thermal).

Three facts about the problem drive every choice below:

1. **The hardware is often absent.** Most development happens without glasses
   on hand, and the Bluetooth link does not work in the simulator at all.
2. **The SDK has ordering rules.** Photo capture is only valid mid-stream, a
   camera needs a started session, permissions are granted out-of-app in Meta
   AI, and the hinge or the wearer can pause things at any time.
3. **Callbacks arrive on arbitrary threads,** from the SDK's publishers, the
   audio tap thread and permission completions.

## Architecture

Dependencies point inward. Each row may depend only on the rows below it.

| Component | Lives in | Responsibility | May depend on |
| --- | --- | --- | --- |
| Views | `platform/ios/App/Views` | SwiftUI screens. Render ViewModel state, forward taps. | ViewModels |
| ViewModels | `platform/ios/App/ViewModels` | One `ObservableObject` per input stream (session, camera, mic, device). Hold `@Published` UI state and expose user intents. No SDK, UIKit or threading code. | Bridge header |
| Composition root | `platform/ios/App/SnapJournalApp.swift` | Builds the bridge, picks real or fake adapters, hands the bridge to each ViewModel. The only place that knows which adapters are live. | Everything above the core |
| Bridge | `platform/ios/Bridge` | `RBSessionBridge`: the only Swift/C++ seam. Translates calls down, marshals callbacks up to the main queue, converts types. No business logic. | Core, Foundation |
| Adapters | `platform/ios/Adapters` | One per input. Wrap MWDATCore/MWDATCamera, AVAudioSession, or fakes; conform to an `RB*` protocol; push results through `RBInputSink`. | Bridge header, Apple/Meta SDKs |
| Core | `core/` | Portable C++17. Domain types, input ports, `SessionEngine` state machine. Never includes a platform header. | C++ standard library only |

## Patterns

Each pattern is here to rule out a specific failure. A pattern whose failure no
longer exists should be removed, not kept out of habit.

| Pattern | Where | Error it rules out | Why it fits here |
| --- | --- | --- | --- |
| **Layered architecture, dependencies inward** | Whole repo; `core/` includes nothing from `platform/` | SDK or UI churn rippling into session logic; session logic that can only be exercised on a phone. | DAT is young and its API moved several times in 2026 (see its CHANGELOG: `deviceStateStream` removed, `StreamError` cases renamed). Inward dependencies confine that churn to the adapters. |
| **Ports and adapters (hexagonal)** | Ports `core/include/rb/i_*.h`; adapters `DATCameraAdapter`, `HFPMicrophoneAdapter`, `DATDeviceStateAdapter`, `FakeCameraAdapter`, plus the C++ fakes in `core/tests` | Logic welded to hardware that is usually not present; untestable session code. | Fact 1. A real adapter and a fake implement the same port, so the UI and the engine run unchanged with no glasses. Adding an input means a new port and a new adapter, with no engine edits. |
| **Explicit finite state machine with guarded transitions** | `SessionEngine::canTransition` and the intent guards in `session_engine.cpp` | Calling the SDK out of order (capture with no stream, start with no registration); crashing on an intent the UI sent at the wrong time. | Fact 2. The SDK's ordering rules become one table that tests can walk. Illegal intents become `onError` instead of undefined SDK behavior. |
| **Observer, single at the core, multicast at the bridge** | `IEngineObserver` (core has exactly one); `RBSessionBridge.addEngineObserver…` fans out to every ViewModel | The engine knowing who displays its events; ViewModels polling the engine. | The core stays ignorant of the UI. The bridge multicasts so each ViewModel subscribes to the one stream it shows. |
| **Facade + PIMPL** | `RBSessionBridge.h` (Obj-C only) over `RBSessionBridge.mm` (all C++) | C++ types leaking into the headers Swift imports, which drags C++ interop into every Swift file. | Swift sees one small Obj-C class. All C++ lives in one `.mm`, so only that file compiles as Objective-C++. |
| **Adapter (object adapter) across the seam** | `ObjCCameraAdapter`, `ObjCMicrophoneAdapter`, `ObjCDeviceStateAdapter` in the `.mm` | Swift adapters needing to implement C++ interfaces. | Each wraps an `id<RB*>` Swift object as an `rb::I*` port, so Swift code only ever implements Obj-C protocols. |
| **Callback sink with a weak back-reference** | `RBInputSink` / `RBInputSinkImpl`; adapters hold the sink `weak` | Async results needing a pull API; retain cycles between the bridge and the adapters it owns. | SDK results are push-based (publishers, taps). Ownership goes one way (bridge → adapter, strong) and results come back the other (adapter → sink, weak). |
| **Thread confinement at the boundary** | `EngineObserverForwarder::fanOut` dispatches to the main queue | ViewModels mutated off the main thread; SwiftUI updates from background queues. | Fact 3. One place moves everything onto main, so ViewModels never contain threading code. |
| **Coarse-grained boundary** | One crossing per photo, per audio buffer, per state change | Per-pixel or per-sample calls across Swift/C++, whose overhead dominates. | Photos arrive as whole JPEGs and audio as ~1024-sample buffers, so crossings stay at tens per second. |
| **MVVM, one ViewModel per input stream** | `SessionViewModel`, `CameraViewModel`, `MicViewModel`, `DeviceViewModel` | Views reaching into the bridge or the SDK; one god ViewModel that changes for every feature. | Feature screens compose the ViewModels they need. The debug `ContentView` composes all four. |
| **Constructor injection and a composition root** | ViewModels take the bridge; `DATCameraAdapter(wearables:)` defaults to `Wearables.shared`; wiring in `SnapJournalApp.init` | Hidden singletons that block fakes and previews. | Swapping fake ↔ real is a one-line change in one file, and tests or previews can pass a mock `WearablesInterface`. |
| **Fakes over mocks** | `FakeCameraAdapter`; `FakeCamera`/`FakeMic`/`FakeDevice` in tests | Tests coupled to call order instead of observable state. | The fakes keep real state (`streaming`, `capturing`), so tests assert outcomes, not interactions. |

### Is this the right shape?

Yes.

- **The right fit:** ports and adapters, the state machine, MVVM and main-thread
  confinement. They map directly to the three facts above. Without them, every
  UI change would need glasses on hand, and the SDK's ordering rules would be
  scattered across view code.
- **A deliberate trade: the C++ core and the Obj-C++ bridge (D-1).** The core
  stays in C++ for performance headroom and portability. Today it only runs the
  state machine and routes events, where speed does not matter yet. The speed
  argument starts to pay once per-frame or per-buffer work (on-device vision,
  audio analysis) moves into the core. Portability pays if the core is reused
  with Meta's Android DAT SDK, which the iOS SDK keeps aligning with. The costs
  are a third language, enums mirrored across the seam (pinned by a test,
  INV-6), and Obj-C names that Swift imports differently than you might expect.
  The tests in the Xcode test target exist to catch exactly those costs.

## Contract

These are the guarantees the code must keep. **Test** names the test that
would fail if the item broke. The tests are the numbered blocks in
`core/tests/test_session_engine.cpp`.

### Invariants

| Id | Guarantee | Test |
| --- | --- | --- |
| INV-1 | Nothing under `core/` includes a platform, Apple or Meta header. | none (no check yet) |
| INV-2 | Session state changes only through the transition table (`idle → registering → ready → streaming ⇄ paused`, `streaming/paused → stopped`, `stopped → streaming`), except `fail()`, which forces `failed` from any state, and `reset()`, which leaves `failed`. | tests 1, 3, 6, 7, 11 |
| INV-3 | `capturePhoto()` reaches the camera only in `streaming`. | tests 2, 9, 10 |
| INV-4 | The engine is only ever called on the main queue, and every engine-to-UI callback runs on the main queue. Adapters may call `RBInputSink` from any thread; the bridge moves each call onto main first (D-7). | none yet |
| INV-5 | No C++ type appears in a header Swift imports. | none |
| INV-6 | `RBSessionState` and `RBStreamEvent` have the same values, in the same order, as `rb::SessionState` and `rb::StreamEvent`. | none (hand-kept) |

### Never

| Id | Never | Test |
| --- | --- | --- |
| NEVER-1 | An illegal intent never crashes or changes state; it emits `onError` and leaves state as it was. | tests 2, 3, 11 |
| NEVER-2 | The phone's built-in mic is never used, even as a fallback; audio is captured only when the glasses HFP input is the active route. | none (on-device only) |
| NEVER-3 | The bridge holds no business logic and no state beyond wiring. | review only |
| NEVER-4 | Nothing crosses the Swift/C++ seam per pixel or per sample. | review only |

### Scenarios

| Id | Scenario | Test |
| --- | --- | --- |
| SCN-1 | Register → stream → snap → hinge closes (pause; mic and device monitoring stay on) → resume → stop (all inputs off). | test 1 |
| SCN-2 | Stop, then start again: the camera is re-armed and capture works. | test 7 |
| SCN-3 | Taking the glasses off behaves like closing the hinge. | test 8 |
| SCN-4 | The engine runs with no adapters attached; capture reports an error. | test 10 |

### Failures

| Id | Failure | Required handling | Test |
| --- | --- | --- | --- |
| FAIL-1 | An adapter hits an unrecoverable error (permission missing, no device, audio setup failed). | `RBInputSink.didFail` → `fail()` → state `failed` with the message; `reset()` returns to `idle`, and the engine is usable again. | test 6 |
| FAIL-2 | A recoverable hiccup: stream interrupted, hinge closed, glasses taken off. | State goes to `paused`, not `failed`; the session stays alive for resume. | tests 4, 8 (engine side only) |
| FAIL-3 | `capturePhoto` is refused by the SDK (a capture is already in flight, or there is no stream). | Log a warning and emit a non-fatal `onError`; the state does not change and the session stays alive (D-8). | none yet |

### Quality targets

None are set yet. Q-1 to Q-3 below are the questions that would set them.

## Decisions and open questions

| Id | Question | Current state |
| --- | --- | --- |
| D-1 | Keep the portable C++ core, or move it to Swift? | **Decided: keep C++**, for performance headroom and portability (see "Is this the right shape?"). |
| D-2 | The `streaming` state merges the SDK's `DeviceSession` (connection) and camera `Stream`. | Merged for v1. `DATCameraAdapter` keeps the `DeviceSession` alive across pause/resume. Split them if a feature needs a connected session with no stream. |
| D-3 | Mic audio goes through Bluetooth HFP, not DAT. | HFP, per Meta's CameraAccess sample. DAT 1.0 adds experimental audio on the camera stream (`audioFramePublisher`); reconsider once it leaves experimental. |
| D-4 | How do ViewModels subscribe to engine events? | **Decided: an Obj-C observer protocol with optional methods**, replacing the six-block `addEngineObserver…` call. Device state crosses as one `RBDeviceState` object instead of four loose values. See "The engine observer protocol" below. |
| D-5 | Is the Xcode project committed? | **Decided: yes.** `*.xcodeproj` is no longer git-ignored; per-user state (`xcuserdata/`) still is. The project lives at `platform/ios/SnapJournal.xcodeproj`. |
| D-6 | What checks the Swift and Obj-C++ code? | **Decided: tests, not a lint script.** An XCTest target (`SnapJournalTests`) builds the Swift code against the bridge header and tests the bridge and ViewModels with fakes. `scripts/test.sh` runs it and the C++ core tests in one command. |
| D-7 | Must adapters call `RBInputSink` on the main thread, or must the bridge make it safe from any thread? | **Decided: the bridge makes it safe.** Every sink call hops to the main queue before it reaches the engine, so the engine needs no locks and only ever runs on main (INV-4). |
| D-8 | How does a refused photo capture surface (FAIL-3)? | **Decided: log it and report it, don't fail.** The adapter logs a warning with `os.Logger` and reports it through the sink; the engine emits `onError` and keeps its state. |
| D-9 | Which mic-permission and audio-route APIs? | **Decided: the current ones,** with the older ones kept beside them and marked deprecated (see "Audio APIs" below). |
| D-10 | Should `reset()` also be allowed from `stopped`? | **Decided: no.** `reset()` is the recovery path out of `failed` only. From `stopped`, the next step is to start again. `idle` means "not registered", which is false after a clean stop because Meta AI still holds the registration. Leaving Meta AI will get its own `unregister` intent when it is built. |
| Q-4 | Storage: local journal in Documents, or iCloud sync? | Not built. Start local. |
| Q-5 | Session UX: one long-lived stream, or start/stop per snap? | One stream. |
| Q-6 | Reconnect policy when the hinge closes or the glasses come off: auto-resume or ask? | The engine pauses; resume is manual. |
| Q-7 | Keep the session alive when the app backgrounds? | No. DAT supports it, at the cost of complexity. |

## The engine observer protocol (D-4)

**What it is.** In Objective-C, a *protocol* is a named list of methods that
any class can promise to implement. It is the same idea as an interface in Java
or a protocol in Swift, and Swift classes can adopt Obj-C protocols directly.
Obj-C protocols can mark methods `@optional`: a class implements only the ones
it cares about, and the caller checks `respondsToSelector:` before calling one.

```objc
NS_SWIFT_UI_ACTOR
@protocol RBEngineObserver <NSObject>
@optional
- (void)engineDidChangeState:(RBSessionState)state;
- (void)engineDidCapturePhoto:(NSData *)jpeg capturedAt:(NSDate *)capturedAt;
- (void)engineDidCaptureAudio:(NSData *)pcm16 sampleRateHz:(NSUInteger)sampleRateHz;
- (void)engineDidUpdateAudioLevel:(float)level;
- (void)engineDidUpdateDeviceState:(RBDeviceState *)deviceState;
- (void)engineDidReportError:(NSString *)message;
@end

// On RBSessionBridge. Observers are held weakly.
- (void)addEngineObserver:(id<RBEngineObserver>)observer;
```

A ViewModel then adopts only what it shows:

```swift
extension MicViewModel: RBEngineObserver {
    func engineDidUpdateAudioLevel(_ level: Float) { self.level = level }
}
```

**What it replaces.** Before, each ViewModel registered by passing six blocks
(Obj-C closures), one per event type, and most were empty
(`audio: { _, _ in }`). Adding one engine event meant editing the core
observer, the forwarder, the block storage, the header, the `.mm` and every
ViewModel.

**Why it is the better fit here:**

- **Each ViewModel says only what it needs.** `MicViewModel` implements one
  method instead of passing five empty blocks.
- **Adding an event touches the protocol, the forwarder and the ViewModels that
  want it.** Nothing else changes, because existing observers simply do not
  implement the new optional method.
- **Main-thread delivery is in the type.** `NS_SWIFT_UI_ACTOR` makes Swift treat
  the protocol as `@MainActor`, so the compiler checks INV-4 on the Swift side.
- **No retain cycles by construction.** The bridge holds observers weakly
  (`NSHashTable weakObjectsHashTable`), so ViewModels need no `[weak self]`
  dance.
- **It is the platform's own idiom.** It is the delegate pattern UIKit uses
  everywhere, so it needs no explanation to an iOS reader.

The trade: optional methods are checked at runtime (`respondsToSelector:`), so
a misspelled method silently never fires. The ViewModel tests catch that.

## Audio APIs (D-9)

The live code uses the current APIs. The older ones are kept as deprecated
wrappers in `HFPMicrophoneAdapter.swift`, so the history and the version limits
are written next to the code that uses them.

| Purpose | Use (live) | Kept, marked deprecated | Versions |
| --- | --- | --- | --- |
| Ask for mic permission | `AVAudioApplication.requestRecordPermission` | `AVAudioSession.requestRecordPermission` | The old call works on iOS 7–16 and is deprecated from iOS 17. The new one needs iOS 17+, which our iOS 17.2 minimum guarantees. |
| Allow the Bluetooth HFP route | `.allowBluetoothHFP` | `.allowBluetooth` | Same option (value `0x4`) under two names; it works on every iOS version. The Xcode 26 SDK deprecates the old name. |

## Known gaps

These are where the code does not yet meet this doc. They are tracked in the
garden report, not fixed here.

- The Swift layer does not compile against the bridge header. Swift imports
  the Obj-C selectors as `attach(_:)` and `addEngineObserver(state:…)`, while
  the Swift code calls `attachCameraInput`, `attachSink` and `withState:`. There
  is also a nonexistent `AVPCMBuffer` type.
- Nothing drives `registrationComplete()` or the real DAT registration flow,
  so the app cannot reach `streaming` (blocks SCN-1 on device).
- `DATCameraAdapter` sends every stream error to `didFail`, so a closed hinge
  fails the session instead of pausing it (breaks FAIL-2).
- `DATCameraAdapter.ensureSession` keeps a session whose `start()` failed, so
  the adapter cannot recover after `reset()` (breaks FAIL-1's "usable again").
- `DATDeviceStateAdapter` is a stub, so `onHingeClosed`/`onTakenOff` are never
  triggered by real hardware.
