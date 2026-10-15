import Foundation

/// ViewModel for glasses device state: battery, hinge, wear, thermal.
@MainActor
final class DeviceViewModel: ObservableObject {
    @Published var batteryPercent: Int = -1
    @Published var hingeOpen = true
    @Published var worn = false
    @Published var thermalWarning = false

    var batteryText: String {
        batteryPercent < 0 ? "unknown" : "\(batteryPercent)%"
    }

    private let bridge: RBSessionBridge

    init(bridge: RBSessionBridge) {
        self.bridge = bridge
        bridge.addEngineObserver(
            withState: { _ in },
            photo: { _, _ in },
            audio: { _, _ in },
            level: { _ in },
            deviceState: { [weak self] battery, hinge, worn, thermal in
                self?.batteryPercent = battery
                self?.hingeOpen = hinge
                self?.worn = worn
                self?.thermalWarning = thermal
            },
            error: { _ in })
    }
}
