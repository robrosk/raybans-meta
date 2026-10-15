import Foundation

/// ViewModel for the camera input: last captured photo + snap intent.
@MainActor
final class CameraViewModel: ObservableObject {
    @Published var lastPhoto: Data?
    @Published var lastPhotoDate: Date?
    @Published var isStreaming = false

    var canSnap: Bool { isStreaming }

    private let bridge: RBSessionBridge

    init(bridge: RBSessionBridge) {
        self.bridge = bridge
        bridge.addEngineObserver(
            withState: { [weak self] s in self?.isStreaming = (s == .streaming) },
            photo: { [weak self] jpeg, date in
                self?.lastPhoto = jpeg
                self?.lastPhotoDate = date
            },
            audio: { _, _ in },
            level: { _ in },
            deviceState: { _, _, _, _ in },
            error: { _ in })
    }

    func capturePhoto() { bridge.capturePhoto() }
}
