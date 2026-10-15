#pragma once

#include <memory>
#include <string>

#include "rb/i_camera_input.h"
#include "rb/i_device_state.h"
#include "rb/i_microphone_input.h"
#include "rb/types.h"

namespace rb {

// The engine re-emits every input event so the UI layer has a single observer.
struct IEngineObserver {
    virtual ~IEngineObserver() = default;
    virtual void onStateChanged(SessionState state) = 0;
    virtual void onPhoto(Frame frame) = 0;
    virtual void onAudio(AudioChunk chunk) = 0;
    virtual void onAudioLevel(float level01) = 0;
    virtual void onDeviceState(DeviceState state) = 0;
    virtual void onError(std::string message) = 0;
};

// Owns the session state machine and routes input events.
// Threading: thread-agnostic. Observer callbacks fire on whatever thread the
// adapter used — the platform bridge marshals them to the main thread.
class SessionEngine : public ICameraObserver,
                      public IMicrophoneObserver,
                      public IDeviceStateObserver {
public:
    SessionEngine();

    void setObserver(IEngineObserver* observer);
    void attachCamera(std::shared_ptr<ICameraInput> camera);
    void attachMicrophone(std::shared_ptr<IMicrophoneInput> microphone);
    void attachDeviceState(std::shared_ptr<IDeviceStateProvider> provider);

    // User intents
    void beginRegistration();
    void registrationComplete();
    void startSession();
    void pauseSession();
    void resumeSession();
    void stopSession();
    void capturePhoto();
    void fail(const std::string& message);
    void reset();

    // Glasses-initiated events
    void onHingeClosed();
    void onTakenOff();

    SessionState state() const { return state_; }

    // ICameraObserver
    void onPhoto(Frame frame) override;
    void onStreamEvent(StreamEvent event) override;
    // IMicrophoneObserver
    void onAudio(AudioChunk chunk) override;
    void onLevel(float level01) override;
    // IDeviceStateObserver
    void onDeviceState(DeviceState state) override;

private:
    void transition(SessionState next);
    bool canTransition(SessionState next) const;
    void illegal(const std::string& what);

    SessionState state_ = SessionState::Idle;
    IEngineObserver* observer_ = nullptr;
    std::shared_ptr<ICameraInput> camera_;
    std::shared_ptr<IMicrophoneInput> microphone_;
    std::shared_ptr<IDeviceStateProvider> deviceState_;
};

}  // namespace rb
