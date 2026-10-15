#pragma once

#include "rb/types.h"

namespace rb {

struct IDeviceStateObserver {
    virtual ~IDeviceStateObserver() = default;
    virtual void onDeviceState(DeviceState state) = 0;
};

// Port: implemented by platform adapters (DAT device state, fakes).
struct IDeviceStateProvider {
    virtual ~IDeviceStateProvider() = default;
    virtual void setObserver(IDeviceStateObserver* observer) = 0;
    virtual void startMonitoring() = 0;
    virtual void stopMonitoring() = 0;
};

}  // namespace rb
