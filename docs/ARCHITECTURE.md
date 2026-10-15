# Architecture

## Layers

Dependencies point inward. The C++ core never includes a platform header.

```
platform/ios/App/Views       SwiftUI — observes ViewModels, nothing else
platform/ios/App/ViewModels  ObservableObject per input stream (MVVM)
platform/ios/Bridge          RBSessionBridge (.h/.mm) — the ONLY Swift<->C++ seam
platform/ios/Adapters        Swift — implement RB* protocols, push via RBInputSink
core/                        pure C++17 — types, input ports, SessionEngine
```

## The C++ core (`core/`)

- `types.h` — `Frame` (JPEG bytes), `AudioChunk` (8 kHz mono PCM),
  `DeviceState`, `SessionState`, `StreamEvent`.
- `i_camera_input.h`, `i_microphone_input.h`, `i_device_state.h` — ports:
  pure-virtual interfaces the adapters implement. New input = new port +
  new adapter, no changes to the engine.
- `session_engine.h/.cpp` — owns the session state machine and re-emits
  every input event to a single `IEngineObserver`.

State machine: `idle -> registering -> ready -> streaming <-> paused`,
`streaming/paused -> stopped`, `* -> failed -> idle` (via `reset()`).
Illegal transitions are rejected with `onError`, never crashes.
Guards encode real constraints, e.g. `capturePhoto()` only in `streaming`.

## The bridge (`platform/ios/Bridge/`)

`RBSessionBridge` is a mechanical translator:

- Down: Swift intent -> C++ `SessionEngine` method.
- Up: C++ observer callback -> re-dispatched to the **main queue** ->
  Obj-C block -> ViewModel `@Published` property -> SwiftUI redraws.
- Adapters: Swift objects conform to `RBCameraInput` / `RBMicrophoneInput` /
  `RBDeviceStateProvider`; the `.mm` wraps each in a C++ adapter
  (`ObjCCameraAdapter` etc.) implementing the `rb::I*` ports. Async results
  flow back through `RBInputSink`.

Rules for the bridge: no business logic, no state beyond wiring. Keep it boring.

## Threading invariant

The engine is thread-agnostic; adapters may call back on any thread. The
bridge normalizes everything onto the main queue. ViewModels never touch a
background thread; the C++ core never knows the main thread exists.

## Boundary discipline

Cross the Swift/C++ line per-photo, per-state-change — never per-pixel or
per-sample. C++ types never appear in headers Swift imports (PIMPL in the
`.mm` keeps them hidden).

## Inputs

| Input | Real adapter | Notes |
|---|---|---|
| Camera video + photo | `DATCameraAdapter` (MWDATCamera) | Photo capture only valid mid-stream |
| Microphone | `HFPMicrophoneAdapter` (AVAudioSession) | NOT via DAT — Bluetooth HFP, 8 kHz mono, OS-level |
| Device state | `DATDeviceStateAdapter` (MWDATCore) | Battery, hinge, wear, thermal |

`FakeCameraAdapter` stands in for hardware during UI development.

## Testing

- `core/tests/` — engine unit tests with fake adapters. Run anywhere:
  `g++ -std=c++17 -I core/include core/src/session_engine.cpp core/tests/test_session_engine.cpp -o /tmp/rb_tests && /tmp/rb_tests`
- SwiftUI previews — ViewModels take the bridge as an init param, so previews
  can inject fakes.
- On-device without glasses — Meta's Mock Device Kit.

## Open design decisions

1. Storage: local-only journal (Documents dir) vs iCloud sync? Start local.
2. Session UX: one long-lived stream while journaling, or start/stop per snap?
3. Captions: manual note field now; auto-caption via model later?
4. Reconnect policy: hinge-close / take-off pauses — auto-resume or ask?
5. Background: keep the session alive when the app backgrounds? (DAT supports
   it; adds complexity.)
