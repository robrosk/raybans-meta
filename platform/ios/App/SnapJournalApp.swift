import SwiftUI

@main
struct SnapJournalApp: App {
    @StateObject private var session: SessionViewModel
    @StateObject private var camera: CameraViewModel
    @StateObject private var mic: MicViewModel
    @StateObject private var device: DeviceViewModel

    init() {
        let bridge = RBSessionBridge()
        // Day-one wiring: fake inputs so the whole stack runs with no hardware
        // and no SDK. Swap for DATCameraAdapter / HFPMicrophoneAdapter /
        // DATDeviceStateAdapter when ready.
        bridge.attachCameraInput(FakeCameraAdapter())

        _session = StateObject(wrappedValue: SessionViewModel(bridge: bridge))
        _camera = StateObject(wrappedValue: CameraViewModel(bridge: bridge))
        _mic = StateObject(wrappedValue: MicViewModel(bridge: bridge))
        _device = StateObject(wrappedValue: DeviceViewModel(bridge: bridge))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .environmentObject(camera)
                .environmentObject(mic)
                .environmentObject(device)
        }
    }
}
