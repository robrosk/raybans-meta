# Garden ledger

Each run adds a section at the top. A Leave entry holds only while its code is
unchanged since that run's base commit.

## 2026-11-24: whole repo

Yardstick: `docs/design/snapjournal.md` (PR #1, written this run), `docs/ARCHITECTURE.md`, READMEs, `docs/SETUP.md`   Base: `562d936`

| Area | Grade | Last run |
| --- | --- | --- |
| Design | C: the superseded `ios/` scaffold (spread 3) was back | none |
| Code | D: four bugs (Swift build break, two in `DATCameraAdapter`, no registration path) | none |
| Tests | D: INV-1, INV-4, INV-5 and INV-6 had no test | none |
| Docs | C: wrong iOS/Xcode minimums in two docs (spread 2) | none |
| Guardrails | B: no weeds; two questions (no check covers Swift/Obj-C++, deprecated audio APIs) | none |
| Runtime | B: no weeds; two questions (threading at the sink, silent photo refusal) | none |

### Pulled
- Remove the superseded `ios/` scaffold again: beds 3, 5, `ios/`, PR https://github.com/robrosk/raybans-meta/pull/2
- Bring the setup docs in line with the code and the DAT SDK: bed 11, `docs/SETUP.md`, `platform/ios/README.md`, PR https://github.com/robrosk/raybans-meta/pull/3 (repeat)
- Test three state-machine edges nothing covered (INV-2, NEVER-1, FAIL-1): bed 6, `core/tests/test_session_engine.cpp`, PR https://github.com/robrosk/raybans-meta/pull/4
- Document the stop-then-restart edge in the architecture overview: bed 11, `docs/ARCHITECTURE.md`, PR https://github.com/robrosk/raybans-meta/pull/5
- Point the device-state TODO at the DAT 1.0 device-state API: bed 11, `platform/ios/Adapters/DATDeviceStateAdapter.swift`, PR https://github.com/robrosk/raybans-meta/pull/6

### Questions
- Keep the C++ core or move to Swift (D-1): decided 2026-11-24, keep C++.
- Replace the six-block observer registration with an Obj-C observer protocol, plus an `RBDeviceState` object (beds 3, 8, 9): decided, do it (D-4).
- `.gitignore` excludes `*.xcodeproj` (beds 13, 15): decided, commit the project (D-5).
- No check covers Swift or Obj-C++ (bed 13): decided, an XCTest target plus `scripts/test.sh` (D-6).
- The bridge calls the engine on the adapter's thread (bed 7): decided, hop to main in the sink (D-7).
- A refused photo capture is silently dropped and nothing logs (bed 17): decided, `os.Logger` plus a non-fatal `onError` (D-8).
- Deprecated `requestRecordPermission` and `.allowBluetooth` (bed 14): decided, use the current APIs and keep the old ones marked deprecated (D-9).
- Should `reset()` be allowed from `stopped`? (Q-1): open.

### Bugs
- The Swift layer does not compile against `RBSessionBridge.h`: Swift imports `attachCameraInput:`/`attachSink:` as `attach(_:)` and `addEngineObserver(withState:…)` as `addEngineObserver(state:…)`, and `AVPCMBuffer` does not exist. Breaks the whole app build.
- No path drives `registrationComplete()` or DAT registration, so the app cannot reach `streaming`: SCN-1.
- `DATCameraAdapter` sends every `StreamError` to `didFail`, so a closed hinge fails the session: FAIL-2.
- `DATCameraAdapter.ensureSession` keeps a session whose `start()` failed, so the adapter cannot recover after `reset()`: FAIL-1.

### Leave
- `SessionEngine::startSession` / `pauseSession` intent guards: load-bearing; `transition()` does not report failure, so without them adapter side effects fire on illegal intents.
- `SessionViewModel.stateName`: mirrors `rb::toString` on purpose; no C++ crosses into Swift (INV-5).
- `MicViewModel.bridge` / `DeviceViewModel.bridge` stored but unread: every ViewModel holds the bridge, so its lifetime does not depend on which ViewModels exist.
- `SessionViewModel.registrationComplete/pause/resume` unused: the intent API mirrors the engine; the UI will call them once the registration bug is fixed.
- Audio crossing the seam per ~1024-sample buffer: within NEVER-4 (not per sample).
- `RBDeviceStateProvider` with a single stub implementation: the design chose one port per input.
- Hand-mirrored `RBSessionState`/`RBStreamEvent` enums: values match today; INV-6 gets a test (D-6).
- `hingeOpen == YES` in `RBSessionBridge.mm`: the values come from Swift `Bool`, always 0 or 1.
- Agent instructions (bed 12): none exist. Security (bed 18): only placeholders, no secrets.

### Backlog
- 1. Remove the unused `#include <cassert>`: bed 5, `core/tests/test_session_engine.cpp`, spread 0, risk 0, cost small
