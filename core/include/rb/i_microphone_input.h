#pragma once

#include "rb/types.h"

namespace rb {

struct IMicrophoneObserver {
    virtual ~IMicrophoneObserver() = default;
    virtual void onAudio(AudioChunk chunk) = 0;
    virtual void onLevel(float level01) = 0;  // 0..1 meter for UI
};

// Port: implemented by platform adapters (AVAudioSession/HFP, fakes).
struct IMicrophoneInput {
    virtual ~IMicrophoneInput() = default;
    virtual void setObserver(IMicrophoneObserver* observer) = 0;
    virtual void startCapture() = 0;
    virtual void stopCapture() = 0;
};

}  // namespace rb
