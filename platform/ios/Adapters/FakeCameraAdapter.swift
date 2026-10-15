import UIKit

/// In-process fake camera for UI development without glasses or the DAT SDK.
/// Generates a timestamped placeholder image per snap.
final class FakeCameraAdapter: NSObject, RBCameraInput {
    private weak var sink: RBInputSink?
    private var streaming = false

    func attachSink(_ sink: RBInputSink) {
        self.sink = sink
    }

    func startStream() {
        streaming = true
        sink?.didStreamEvent(.started)
    }

    func stopStream() {
        streaming = false
        sink?.didStreamEvent(.stopped)
    }

    func capturePhoto() {
        guard streaming else { return }
        let size = CGSize(width: 320, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let text = "fake frame\n\(Date())" as NSString
            text.draw(at: CGPoint(x: 16, y: 100),
                      withAttributes: [.foregroundColor: UIColor.white])
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.8) else { return }
        // Simulate async capture latency.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.sink?.didCapturePhoto(jpeg, width: 320, height: 240)
        }
    }
}
