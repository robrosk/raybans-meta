#pragma once

#include <chrono>
#include <cstdint>
#include <string>
#include <vector>

namespace rb {

// Lifecycle of a glasses session. Only one session runs at a time.
enum class SessionState {
    Idle,         // nothing registered yet
    Registering,  // user is confirming in the Meta AI app
    Ready,        // registered, no active session
    Streaming,    // session active, camera stream running
    Paused,       // stream paused (hinge closed, taken off, user pause)
    Stopped,      // session ended cleanly
    Failed,       // unrecoverable error; call reset() to recover
};

// Events coming from a camera stream.
// NOTE: order mirrors RBStreamEvent in RBSessionBridge.h — keep in sync.
enum class StreamEvent { Started, Paused, Resumed, Stopped, Interrupted };

// A single captured photo.
struct Frame {
    std::vector<uint8_t> jpeg;  // JPEG-encoded bytes
    uint32_t width = 0;
    uint32_t height = 0;
    std::chrono::system_clock::time_point capturedAt{};
};

// A chunk of microphone audio. Glasses mics arrive over Bluetooth HFP:
// 8 kHz mono 16-bit PCM.
struct AudioChunk {
    std::vector<int16_t> pcm16;
    uint32_t sampleRateHz = 8000;
};

struct DeviceState {
    int batteryPercent = -1;  // -1 == unknown
    bool hingeOpen = true;
    bool worn = false;  // wear detection
    bool thermalWarning = false;
};

inline const char* toString(SessionState s) {
    switch (s) {
        case SessionState::Idle: return "idle";
        case SessionState::Registering: return "registering";
        case SessionState::Ready: return "ready";
        case SessionState::Streaming: return "streaming";
        case SessionState::Paused: return "paused";
        case SessionState::Stopped: return "stopped";
        case SessionState::Failed: return "failed";
    }
    return "unknown";
}

}  // namespace rb
