#include "rb/session_engine.h"

namespace rb {

SessionEngine::SessionEngine() = default;

void SessionEngine::setObserver(IEngineObserver* observer) { observer_ = observer; }

void SessionEngine::attachCamera(std::shared_ptr<ICameraInput> camera) {
    camera_ = std::move(camera);
    if (camera_) camera_->setObserver(this);
}

void SessionEngine::attachMicrophone(std::shared_ptr<IMicrophoneInput> microphone) {
    microphone_ = std::move(microphone);
    if (microphone_) microphone_->setObserver(this);
}

void SessionEngine::attachDeviceState(std::shared_ptr<IDeviceStateProvider> provider) {
    deviceState_ = std::move(provider);
    if (deviceState_) deviceState_->setObserver(this);
}

bool SessionEngine::canTransition(SessionState next) const {
    switch (state_) {
        case SessionState::Idle:
            return next == SessionState::Registering;
        case SessionState::Registering:
            return next == SessionState::Ready || next == SessionState::Failed;
        case SessionState::Ready:
            return next == SessionState::Streaming || next == SessionState::Failed;
        case SessionState::Streaming:
            return next == SessionState::Paused || next == SessionState::Stopped ||
                   next == SessionState::Failed;
        case SessionState::Paused:
            return next == SessionState::Streaming || next == SessionState::Stopped ||
                   next == SessionState::Failed;
        case SessionState::Stopped:
            return next == SessionState::Streaming || next == SessionState::Idle ||
                   next == SessionState::Failed;
        case SessionState::Failed:
            return next == SessionState::Idle;
    }
    return false;
}

void SessionEngine::transition(SessionState next) {
    if (!canTransition(next)) {
        illegal("illegal state transition");
        return;
    }
    state_ = next;
    if (observer_) observer_->onStateChanged(state_);
}

void SessionEngine::illegal(const std::string& what) {
    if (observer_) observer_->onError(what + " (state=" + toString(state_) + ")");
}

void SessionEngine::beginRegistration() { transition(SessionState::Registering); }
void SessionEngine::registrationComplete() { transition(SessionState::Ready); }

void SessionEngine::startSession() {
    if (state_ != SessionState::Ready && state_ != SessionState::Stopped &&
        state_ != SessionState::Paused) {
        illegal("startSession requires Ready, Stopped or Paused");
        return;
    }
    transition(SessionState::Streaming);
    if (camera_) camera_->startStream();
    if (microphone_) microphone_->startCapture();
    if (deviceState_) deviceState_->startMonitoring();
}

void SessionEngine::pauseSession() {
    if (state_ != SessionState::Streaming) {
        illegal("pauseSession requires Streaming");
        return;
    }
    if (camera_) camera_->stopStream();
    transition(SessionState::Paused);
}

void SessionEngine::resumeSession() { startSession(); }

void SessionEngine::stopSession() {
    if (state_ != SessionState::Streaming && state_ != SessionState::Paused) {
        illegal("stopSession requires Streaming or Paused");
        return;
    }
    if (camera_) camera_->stopStream();
    if (microphone_) microphone_->stopCapture();
    if (deviceState_) deviceState_->stopMonitoring();
    transition(SessionState::Stopped);
}

void SessionEngine::capturePhoto() {
    if (state_ != SessionState::Streaming) {
        illegal("capturePhoto requires an active stream");
        return;
    }
    if (!camera_) {
        illegal("capturePhoto with no camera attached");
        return;
    }
    camera_->capturePhoto();
}

void SessionEngine::fail(const std::string& message) {
    if (state_ == SessionState::Failed) return;
    // Failed is reachable from every state except via the normal table; force it.
    state_ = SessionState::Failed;
    if (observer_) {
        observer_->onError(message);
        observer_->onStateChanged(state_);
    }
}

void SessionEngine::reset() { transition(SessionState::Idle); }

void SessionEngine::onHingeClosed() {
    if (state_ == SessionState::Streaming) {
        if (camera_) camera_->stopStream();
        transition(SessionState::Paused);
    }
}

void SessionEngine::onTakenOff() { onHingeClosed(); }

// --- Input event routing: re-emit to the engine observer ---

void SessionEngine::onPhoto(Frame frame) {
    if (observer_) observer_->onPhoto(std::move(frame));
}

void SessionEngine::onStreamEvent(StreamEvent event) {
    if (event == StreamEvent::Interrupted && state_ == SessionState::Streaming) {
        transition(SessionState::Paused);
    }
}

void SessionEngine::onAudio(AudioChunk chunk) {
    if (observer_) observer_->onAudio(std::move(chunk));
}

void SessionEngine::onLevel(float level01) {
    if (observer_) observer_->onAudioLevel(level01);
}

void SessionEngine::onDeviceState(DeviceState state) {
    if (observer_) observer_->onDeviceState(state);
}

}  // namespace rb
