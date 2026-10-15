import Foundation

/// ViewModel for the session lifecycle. Owns user intents (register, start,
/// pause, resume, stop) and surfaces engine state + errors.
@MainActor
final class SessionViewModel: ObservableObject {
    @Published var state: RBSessionState = .idle
    @Published var lastError: String?

    var stateName: String {
        switch state {
        case .idle: return "idle"
        case .registering: return "registering"
        case .ready: return "ready"
        case .streaming: return "streaming"
        case .paused: return "paused"
        case .stopped: return "stopped"
        case .failed: return "failed"
        @unknown default: return "unknown"
        }
    }

    private let bridge: RBSessionBridge

    init(bridge: RBSessionBridge) {
        self.bridge = bridge
        bridge.addEngineObserver(
            withState: { [weak self] s in
                self?.state = s
                if s != .failed { self?.lastError = nil }
            },
            photo: { _, _ in },
            audio: { _, _ in },
            level: { _ in },
            deviceState: { _, _, _, _ in },
            error: { [weak self] msg in self?.lastError = msg })
    }

    func register() { bridge.beginRegistration() }
    func registrationComplete() { bridge.registrationComplete() }
    func start() { bridge.startSession() }
    func pause() { bridge.pauseSession() }
    func resume() { bridge.resumeSession() }
    func stop() { bridge.stopSession() }
}
