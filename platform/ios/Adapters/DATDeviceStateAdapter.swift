import Foundation
import MWDATCore

/// Device state (battery, hinge, wear detection, thermal) from the DAT SDK.
///
/// TODO: wire to MWDATCore's device APIs (DAT 1.0+; `deviceStateStream(for:)`
/// was removed in 1.0). Discovery path, per the SDK:
///   session.device (DeviceSession.device) or wearables.deviceForIdentifier(_:) -> Device?
///   then device.addDeviceStateListener { (state: DeviceState) in ... }, which
///   fires immediately and on every change. Map batteryLevel, hingeState,
///   donState and thermalLevel, forwarded as:
///     sink?.didUpdateDeviceState(batteryPercent, hingeOpen:, worn:, thermalWarning:)
/// See the MWDATCore API reference + the DAT CHANGELOG (1.0.0, "Device state on Device").
final class DATDeviceStateAdapter: NSObject, RBDeviceStateProvider {
    private weak var sink: RBInputSink?

    func attachSink(_ sink: RBInputSink) {
        self.sink = sink
    }

    func startMonitoring() {
        // TODO: MWDATCore device-state wiring (see above)
    }

    func stopMonitoring() {
        // TODO: tear down observation
    }
}
