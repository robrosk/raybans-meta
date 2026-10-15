import Foundation

/// Real camera input backed by the DAT SDK (MWDATCamera).
///
/// TODO: add the SwiftPM package https://github.com/facebook/meta-wearables-dat-ios
/// and wire:
///   startStream  -> session/addCamera stream start (resolution + fps selection)
///   stopStream   -> stream stop
///   capturePhoto -> single-frame capture DURING the active stream, then
///                   sink?.didCapturePhoto(jpeg, width:, height:)
/// Reference: https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples
final class DATCameraAdapter: NSObject, RBCameraInput {
    private weak var sink: RBInputSink?

    func attachSink(_ sink: RBInputSink) {
        self.sink = sink
    }

    func startStream() {
        // TODO: MWDATCamera wiring
    }

    func stopStream() {
        // TODO: MWDATCamera wiring
    }

    func capturePhoto() {
        // TODO: MWDATCamera single-frame capture -> sink?.didCapturePhoto(...)
    }
}
