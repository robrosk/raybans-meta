import AVFoundation
import Foundation

/// Glasses microphone input. NOTE: the mic does NOT come through the DAT SDK —
/// it arrives over Bluetooth HFP as 8 kHz mono, captured with AVAudioSession.
///
/// TODO: wire up:
///   - AVAudioSession category .playAndRecord with .allowBluetoothHFP (actually
///     .allowBluetooth for HFP input routing)
///   - AVAudioEngine input tap -> 8 kHz mono PCM -> sink?.didCaptureAudio(...)
///   - Level metering -> sink?.didAudioLevel(...)
/// Microphone permission goes through the iOS system dialog, not Meta AI.
final class HFPMicrophoneAdapter: NSObject, RBMicrophoneInput {
    private weak var sink: RBInputSink?

    func attachSink(_ sink: RBInputSink) {
        self.sink = sink
    }

    func startCapture() {
        // TODO: AVAudioSession + AVAudioEngine wiring
    }

    func stopCapture() {
        // TODO: tear down engine
    }
}
