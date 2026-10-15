import Foundation

/// Device state (battery, hinge, wear detection, thermal) from the DAT SDK.
///
/// TODO: add the SwiftPM package https://github.com/facebook/meta-wearables-dat-ios
/// and wire startMonitoring to the SDK's device-state publisher, forwarding:
///   sink?.didUpdateDeviceState(batteryPercent, hingeOpen:, worn:, thermalWarning:)
/// Reference: https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples
final class DATDeviceStateAdapter: NSObject, RBDeviceStateProvider {
    private weak var sink: RBInputSink?

    func attachSink(_ sink: RBInputSink) {
        self.sink = sink
    }

    func startMonitoring() {
        // TODO: MWDATCore device-state wiring
    }

    func stopMonitoring() {
        // TODO: tear down observation
    }
}
