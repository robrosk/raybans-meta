import Foundation

/// ViewModel for the microphone input: live level meter.
@MainActor
final class MicViewModel: ObservableObject {
    @Published var level: Float = 0

    private let bridge: RBSessionBridge

    init(bridge: RBSessionBridge) {
        self.bridge = bridge
        bridge.addEngineObserver(
            withState: { _ in },
            photo: { _, _ in },
            audio: { _, _ in },
            level: { [weak self] l in self?.level = l },
            deviceState: { _, _, _, _ in },
            error: { _ in })
    }
}
