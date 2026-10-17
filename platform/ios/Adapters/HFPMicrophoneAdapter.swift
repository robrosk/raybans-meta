import AVFoundation
import Foundation

/// Glasses microphone over Bluetooth HFP, captured app-side with AVAudioEngine.
///
/// The DAT SDK does not deliver mic audio — per Meta's CameraAccess sample
/// (Media/AudioInputHandler.swift), the app taps the HFP input route directly
/// and never falls back to the phone mic. Buffers are converted Float32 ->
/// Int16 PCM for the engine, and an RMS level is reported for UI meters.
///
/// Production hardening not yet done here (see the sample): interruption
/// handling, route-change observers, media-services reset. This scaffold
/// covers the happy path.
final class HFPMicrophoneAdapter: NSObject, RBMicrophoneInput {
    private weak var sink: RBInputSink?
    private let audioEngine = AVAudioEngine()
    private var capturing = false

    func attachSink(_ sink: RBInputSink) {
        self.sink = sink
    }

    func startCapture() {
        Task { @MainActor [weak self] in self?.startCaptureMain() }
    }

    func stopCapture() {
        Task { @MainActor [weak self] in self?.stopCaptureMain() }
    }

    // MARK: - Private (all MainActor)

    @MainActor
    private func startCaptureMain() {
        guard !capturing else { return }
        capturing = true
        // Mic permission is an iOS system dialog (not Meta AI).
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                Task { @MainActor [weak self] in
                    self?.capturing = false
                    self?.sink?.didFail("Microphone permission denied")
                }
                return
            }
            Task { @MainActor [weak self] in self?.beginTap() }
        }
    }

    @MainActor
    private func beginTap() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.allowBluetooth])
            // Prefer the glasses HFP input when it's available.
            if let hfp = session.availableInputs?.first(where: { $0.portType == .bluetoothHFP }) {
                try session.setPreferredInput(hfp)
            }
            try session.setActive(true)
        } catch {
            sink?.didFail("Audio session setup failed: \(error.localizedDescription)")
            capturing = false
            return
        }
        guard session.currentRoute.inputs.contains(where: { $0.portType == .bluetoothHFP }) else {
            sink?.didFail("Glasses microphone is not the active input")
            capturing = false
            return
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.handleBuffer(buffer)
        }
        do {
            try audioEngine.start()
        } catch {
            sink?.didFail("Couldn't start audio capture: \(error.localizedDescription)")
            capturing = false
        }
    }

    @MainActor
    private func stopCaptureMain() {
        guard capturing else { return }
        capturing = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        sink?.didAudioLevel(0)
    }

    /// Runs on the audio tap thread: mix to mono, convert to Int16, compute RMS.
    private func handleBuffer(_ buffer: AVPCMBuffer) {
        guard capturing, let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frames > 0, channelCount > 0 else { return }

        var pcm = [Int16](repeating: 0, count: frames)
        var sum: Float = 0
        for i in 0..<frames {
            var sample: Float = 0
            for c in 0..<channelCount { sample += channels[c][i] }
            sample /= Float(channelCount)
            sum += sample * sample
            pcm[i] = Int16(max(-1.0, min(1.0, sample)) * Float(Int16.max))
        }
        let level = sqrt(sum / Float(frames))
        let data = pcm.withUnsafeBytes { Data($0) }
        let sampleRate = UInt(buffer.format.sampleRate)
        DispatchQueue.main.async { [weak self] in
            self?.sink?.didCaptureAudio(data, sampleRateHz: sampleRate)
            self?.sink?.didAudioLevel(level)
        }
    }
}
