// Unit tests for SessionEngine. Pure C++ — no Apple/Meta frameworks, no hardware.
// Build: g++ -std=c++17 -I../include ../src/session_engine.cpp test_session_engine.cpp -o rb_tests

#include <cassert>
#include <iostream>
#include <string>

#include "rb/session_engine.h"

#define CHECK(cond)                                                              \
    do {                                                                         \
        if (!(cond)) {                                                           \
            std::cerr << "FAIL line " << __LINE__ << ": " #cond "\n";            \
            return 1;                                                            \
        }                                                                        \
    } while (0)

namespace {

struct FakeCamera : rb::ICameraInput {
    rb::ICameraObserver* obs = nullptr;
    bool streaming = false;
    int photosRequested = 0;

    void setObserver(rb::ICameraObserver* o) override { obs = o; }
    void startStream() override {
        streaming = true;
        if (obs) obs->onStreamEvent(rb::StreamEvent::Started);
    }
    void stopStream() override {
        streaming = false;
        if (obs) obs->onStreamEvent(rb::StreamEvent::Stopped);
    }
    void capturePhoto() override {
        ++photosRequested;
        if (streaming && obs) {
            rb::Frame f;
            f.jpeg = {0xFF, 0xD8, 0xFF, 0xD9};  // minimal JPEG markers
            f.width = 2;
            f.height = 2;
            obs->onPhoto(std::move(f));
        }
    }
};

struct FakeMic : rb::IMicrophoneInput {
    rb::IMicrophoneObserver* obs = nullptr;
    bool capturing = false;

    void setObserver(rb::IMicrophoneObserver* o) override { obs = o; }
    void startCapture() override { capturing = true; }
    void stopCapture() override { capturing = false; }
};

struct FakeDevice : rb::IDeviceStateProvider {
    rb::IDeviceStateObserver* obs = nullptr;
    bool monitoring = false;

    void setObserver(rb::IDeviceStateObserver* o) override { obs = o; }
    void startMonitoring() override { monitoring = true; }
    void stopMonitoring() override { monitoring = false; }
};

struct Probe : rb::IEngineObserver {
    rb::SessionState lastState = rb::SessionState::Idle;
    int photos = 0;
    int audioChunks = 0;
    float lastLevel = -1.0f;
    rb::DeviceState lastDevice{};
    std::string lastError;

    void onStateChanged(rb::SessionState s) override { lastState = s; }
    void onPhoto(rb::Frame) override { ++photos; }
    void onAudio(rb::AudioChunk) override { ++audioChunks; }
    void onAudioLevel(float l) override { lastLevel = l; }
    void onDeviceState(rb::DeviceState s) override { lastDevice = s; }
    void onError(std::string m) override { lastError = std::move(m); }
};

void toStreaming(rb::SessionEngine& engine, std::shared_ptr<FakeCamera> camera,
                 std::shared_ptr<FakeMic> mic, std::shared_ptr<FakeDevice> dev,
                 Probe& probe) {
    engine.setObserver(&probe);
    engine.attachCamera(camera);
    engine.attachMicrophone(mic);
    engine.attachDeviceState(dev);
    engine.beginRegistration();
    engine.registrationComplete();
    engine.startSession();
}

}  // namespace

int main() {
    // 1. Happy path: register -> stream -> snap -> hinge -> resume -> stop.
    {
        rb::SessionEngine engine;
        Probe probe;
        auto camera = std::make_shared<FakeCamera>();
        auto mic = std::make_shared<FakeMic>();
        auto dev = std::make_shared<FakeDevice>();
        toStreaming(engine, camera, mic, dev, probe);
        CHECK(probe.lastState == rb::SessionState::Streaming);
        CHECK(camera->streaming);
        CHECK(mic->capturing);
        CHECK(dev->monitoring);

        engine.capturePhoto();
        CHECK(probe.photos == 1);
        CHECK(camera->photosRequested == 1);

        engine.onHingeClosed();
        CHECK(probe.lastState == rb::SessionState::Paused);
        CHECK(!camera->streaming);
        // Pause keeps mic + device monitoring alive (cheap; needed for auto-resume).
        CHECK(mic->capturing);
        CHECK(dev->monitoring);

        engine.resumeSession();
        CHECK(probe.lastState == rb::SessionState::Streaming);
        CHECK(camera->streaming);

        engine.stopSession();
        CHECK(probe.lastState == rb::SessionState::Stopped);
        CHECK(!camera->streaming);
        CHECK(!mic->capturing);
        CHECK(!dev->monitoring);
    }

    // 2. capturePhoto outside Streaming is rejected, not crashed.
    {
        rb::SessionEngine engine;
        Probe probe;
        auto camera = std::make_shared<FakeCamera>();
        engine.setObserver(&probe);
        engine.attachCamera(camera);

        engine.capturePhoto();
        CHECK(probe.photos == 0);
        CHECK(camera->photosRequested == 0);
        CHECK(!probe.lastError.empty());
        CHECK(probe.lastState == rb::SessionState::Idle);
    }

    // 3. Illegal transitions are guarded.
    {
        rb::SessionEngine engine;
        Probe probe;
        engine.setObserver(&probe);

        engine.startSession();  // Idle -> Streaming is illegal
        CHECK(probe.lastState == rb::SessionState::Idle);
        CHECK(!probe.lastError.empty());

        engine.pauseSession();  // Idle -> Paused is illegal
        CHECK(probe.lastState == rb::SessionState::Idle);
    }

    // 4. Interrupted stream pauses the session.
    {
        rb::SessionEngine engine;
        Probe probe;
        auto camera = std::make_shared<FakeCamera>();
        toStreaming(engine, camera, std::make_shared<FakeMic>(),
                    std::make_shared<FakeDevice>(), probe);
        camera->obs->onStreamEvent(rb::StreamEvent::Interrupted);
        CHECK(probe.lastState == rb::SessionState::Paused);
    }

    // 5. Mic + device events are re-emitted.
    {
        rb::SessionEngine engine;
        Probe probe;
        engine.setObserver(&probe);

        rb::AudioChunk chunk;
        chunk.pcm16 = {1, 2, 3};
        engine.onAudio(std::move(chunk));
        CHECK(probe.audioChunks == 1);

        engine.onLevel(0.5f);
        CHECK(probe.lastLevel == 0.5f);

        rb::DeviceState ds;
        ds.batteryPercent = 80;
        engine.onDeviceState(ds);
        CHECK(probe.lastDevice.batteryPercent == 80);
    }

    // 6. fail() + reset() recovery.
    {
        rb::SessionEngine engine;
        Probe probe;
        engine.setObserver(&probe);
        engine.beginRegistration();
        engine.fail("boom");
        CHECK(probe.lastState == rb::SessionState::Failed);
        CHECK(!probe.lastError.empty());
        engine.reset();
        CHECK(probe.lastState == rb::SessionState::Idle);
        // And the engine is usable again after reset.
        engine.beginRegistration();
        CHECK(probe.lastState == rb::SessionState::Registering);
    }

    // 7. Restart after stop: Stopped -> Streaming works, adapters re-armed.
    {
        rb::SessionEngine engine;
        Probe probe;
        auto camera = std::make_shared<FakeCamera>();
        toStreaming(engine, camera, std::make_shared<FakeMic>(),
                    std::make_shared<FakeDevice>(), probe);
        engine.stopSession();
        CHECK(probe.lastState == rb::SessionState::Stopped);

        probe.lastError.clear();
        engine.startSession();
        CHECK(probe.lastError.empty());
        CHECK(probe.lastState == rb::SessionState::Streaming);
        CHECK(camera->streaming);
        engine.capturePhoto();
        CHECK(probe.photos == 1);
    }

    // 8. onTakenOff behaves like onHingeClosed.
    {
        rb::SessionEngine engine;
        Probe probe;
        auto camera = std::make_shared<FakeCamera>();
        toStreaming(engine, camera, std::make_shared<FakeMic>(),
                    std::make_shared<FakeDevice>(), probe);
        engine.onTakenOff();
        CHECK(probe.lastState == rb::SessionState::Paused);
        CHECK(!camera->streaming);
    }

    // 9. capturePhoto after stop is rejected.
    {
        rb::SessionEngine engine;
        Probe probe;
        auto camera = std::make_shared<FakeCamera>();
        toStreaming(engine, camera, std::make_shared<FakeMic>(),
                    std::make_shared<FakeDevice>(), probe);
        engine.stopSession();
        probe.lastError.clear();
        engine.capturePhoto();
        CHECK(probe.photos == 0);
        CHECK(!probe.lastError.empty());
    }

    // 10. Engine works with no adapters attached (null-safe).
    {
        rb::SessionEngine engine;
        Probe probe;
        engine.setObserver(&probe);
        engine.beginRegistration();
        engine.registrationComplete();
        engine.startSession();
        CHECK(probe.lastState == rb::SessionState::Streaming);
        engine.capturePhoto();  // no camera: error, no crash
        CHECK(!probe.lastError.empty());
        engine.stopSession();
        CHECK(probe.lastState == rb::SessionState::Stopped);
    }

    // 11. Double pause is rejected; state unchanged.
    {
        rb::SessionEngine engine;
        Probe probe;
        auto camera = std::make_shared<FakeCamera>();
        toStreaming(engine, camera, std::make_shared<FakeMic>(),
                    std::make_shared<FakeDevice>(), probe);
        engine.pauseSession();
        CHECK(probe.lastState == rb::SessionState::Paused);
        probe.lastError.clear();
        engine.pauseSession();
        CHECK(!probe.lastError.empty());
        CHECK(probe.lastState == rb::SessionState::Paused);
    }

    std::cout << "all tests passed\n";
    return 0;
}
