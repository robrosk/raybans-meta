#pragma once

#include "rb/types.h"

namespace rb {

// Implemented by the engine (or any consumer) to receive camera events.
struct ICameraObserver {
    virtual ~ICameraObserver() = default;
    virtual void onPhoto(Frame frame) = 0;
    virtual void onStreamEvent(StreamEvent event) = 0;
};

// Port: implemented by platform adapters (DAT SDK, fakes, mocks).
// Contract: capturePhoto() is only meaningful while streaming.
struct ICameraInput {
    virtual ~ICameraInput() = default;
    virtual void setObserver(ICameraObserver* observer) = 0;
    virtual void startStream() = 0;
    virtual void stopStream() = 0;
    virtual void capturePhoto() = 0;
};

}  // namespace rb
