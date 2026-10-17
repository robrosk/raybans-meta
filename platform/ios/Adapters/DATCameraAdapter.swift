import Foundation
import MWDATCamera
import MWDATCore
import UIKit

/// Real camera input backed by the DAT SDK.
///
/// Maps engine intents onto the SDK lifecycle (per the official CameraAccess
/// sample and Meta's camera-streaming guide):
///   startStream  -> createSession(deviceSelector:) [once] -> session.start()
///                   -> addCamera(config:) -> camera.stream.start()
///   stopStream   -> camera.stop() (cascades to the stream; session is kept —
///                   the SDK treats a connected session with no stream as cheap
///                   and reusable, which makes resume instant)
///   capturePhoto -> stream.capturePhoto(format: .jpeg); the JPEG arrives via
///                   photoDataPublisher -> sink.didCapturePhoto
///
/// Permission: checkPermissionStatus(.camera) is a silent query. requestPermission
/// would app-switch to Meta AI, so we only start when already granted — the
/// confirm-then-redirect UX is a later step (see the sample's
/// confirmCameraPermissionRedirect).
final class DATCameraAdapter: NSObject, RBCameraInput {
    private weak var sink: RBInputSink?
    private let wearables: WearablesInterface
    private var session: DeviceSession?
    private var camera: MWDATCamera.Camera?
    private let tokens = ListenerTokenBag()

    init(wearables: WearablesInterface = Wearables.shared) {
        self.wearables = wearables
        super.init()
    }

    func attachSink(_ sink: RBInputSink) {
        self.sink = sink
    }

    func startStream() {
        Task { @MainActor [weak self] in await self?.startStreamAsync() }
    }

    func stopStream() {
        Task { @MainActor [weak self] in self?.stopStreamMain() }
    }

    func capturePhoto() {
        Task { @MainActor [weak self] in
            guard let stream = self?.camera?.stream else { return }
            // Returns false when a capture is already in flight — then no
            // photoDataPublisher event will arrive for this attempt.
            _ = stream.capturePhoto(format: .jpeg)
        }
    }

    // MARK: - Private (all MainActor)

    @MainActor
    private func startStreamAsync() async {
        do {
            guard try await wearables.checkPermissionStatus(.camera) == .granted else {
                sink?.didFail("Camera permission not granted")
                return
            }
            try await ensureSession()
            guard camera == nil, let session else { return }
            // .raw yields decoded frames (frame.makeUIImage()); .medium is 504x896.
            // Lower resolution/FPS = less Bluetooth compression = sharper frames.
            let config = StreamConfiguration(videoCodec: .raw, resolution: .medium, frameRate: 24)
            guard let camera = try session.addCamera(config: config) else {
                sink?.didFail("Couldn't attach the camera")
                return
            }
            self.camera = camera
            let stream = camera.stream
            stream.statePublisher.listen { [weak self] state in
                Task { @MainActor [weak self] in self?.forwardStreamState(state) }
            }.store(in: tokens)
            stream.photoDataPublisher.listen { [weak self] photo in
                Task { @MainActor [weak self] in self?.forwardPhoto(photo) }
            }.store(in: tokens)
            stream.errorPublisher.listen { [weak self] error in
                Task { @MainActor [weak self] in
                    // Typed errors: .permissionDenied, .deviceNotConnected,
                    // .hingesClosed, .thermalHot, .batteryLow, .photoCaptureFailed
                    self?.sink?.didFail(error.localizedDescription)
                }
            }.store(in: tokens)
            stream.start()
        } catch {
            sink?.didFail(error.localizedDescription)
        }
    }

    @MainActor
    private func ensureSession() async throws {
        if session != nil { return }
        let selector = AutoDeviceSelector(wearables: wearables)
        let session = try wearables.createSession(deviceSelector: selector)
        self.session = session
        try session.start()
        for await state in session.stateStream() {
            if state == .started { break }
        }
    }

    @MainActor
    private func stopStreamMain() {
        // Stopping the camera cascades to its stream child and detaches it from
        // the session, so the next startStream() uses a fresh addCamera().
        camera?.stop()
        camera = nil
        tokens.clear()
    }

    @MainActor
    private func forwardStreamState(_ state: StreamState) {
        switch state {
        case .streaming: sink?.didStreamEvent(.started)
        case .paused: sink?.didStreamEvent(.paused)
        case .stopped: sink?.didStreamEvent(.stopped)
        default: break // .starting/.stopping/.waitingForDevice are transient
        }
    }

    @MainActor
    private func forwardPhoto(_ photo: PhotoData) {
        let data = photo.data // .format is .jpeg or .heic; we requested .jpeg
        let size = UIImage(data: data)?.size ?? .zero
        sink?.didCapturePhoto(data, width: UInt(size.width), height: UInt(size.height))
    }
}
