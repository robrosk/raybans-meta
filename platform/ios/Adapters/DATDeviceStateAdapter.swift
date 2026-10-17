import Foundation
import MWDATCore

/// Device state (battery, hinge, wear detection, thermal) from the DAT SDK.
///
/// TODO: wire to MWDATCore's device APIs. Discovery path, per the SDK:
///   wearables.deviceForIdentifier(_:) -> Device?
///   then the Device's state publishers (battery/hinge/thermal), forwarded as:
///     sink?.didUpdateDeviceState(batteryPercent, hingeOpen:, worn:, thermalWarning:)
/// See the MWDATCore API reference + the CameraAccess sample's
/// device-compatibility monitoring (addCompatibilityListener) for the pattern.
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
