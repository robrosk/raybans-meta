# core/ — portable C++ engine

Pure C++17. No Apple frameworks, no Meta SDK, no UI. This is deliberate: the
core must compile anywhere (Linux CI, macOS, later Android NDK).

## What's here

- `include/rb/types.h` — domain types: `Frame`, `AudioChunk`, `DeviceState`, `SessionState`
- `include/rb/i_*` — input ports (pure-virtual interfaces). Platform adapters implement these.
- `include/rb/session_engine.h` / `src/session_engine.cpp` — owns the session
  state machine and routes input events to a single `IEngineObserver`.

## Invariants

1. **Dependencies point inward.** The core never includes platform headers.
   Platform code adapts *to* these interfaces, never the reverse.
2. **Thread-agnostic.** The engine fires observer callbacks on whatever thread
   the adapter used. The platform bridge marshals everything to the main
   thread before it reaches UI code.
3. **Narrow, chunky boundary.** Cross the Swift/C++ line per-photo,
   per-state-change — never per-pixel or per-sample.

## Build & test

```sh
cd core
g++ -std=c++17 -Iinclude src/session_engine.cpp tests/test_session_engine.cpp -o /tmp/rb_tests
/tmp/rb_tests
```

Or with CMake:

```sh
cmake -B build && cmake --build build && ctest --test-dir build
```
