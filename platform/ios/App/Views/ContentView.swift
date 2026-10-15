import SwiftUI

/// Debug "input monitor": shows every input stream live. Features will be
/// built as separate views composing the same ViewModels.
struct ContentView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var camera: CameraViewModel
    @EnvironmentObject var mic: MicViewModel
    @EnvironmentObject var device: DeviceViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    Text("State: \(session.stateName)")
                    HStack {
                        Button("Register") { session.register() }
                        Button("Start") { session.start() }
                        Button("Stop") { session.stop() }
                    }
                    .buttonStyle(.bordered)
                }

                Section("Camera") {
                    Button("Snap photo") { camera.capturePhoto() }
                        .disabled(!camera.canSnap)
                    if let data = camera.lastPhoto, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                    } else {
                        Text("No photo yet").foregroundStyle(.secondary)
                    }
                }

                Section("Microphone") {
                    Text(String(format: "Level: %.2f", mic.level))
                }

                Section("Glasses") {
                    LabeledContent("Battery", value: device.batteryText)
                    LabeledContent("Hinge", value: device.hingeOpen ? "open" : "closed")
                    LabeledContent("Worn", value: device.worn ? "yes" : "no")
                    if device.thermalWarning {
                        Text("Thermal warning").foregroundStyle(.red)
                    }
                }

                if let error = session.lastError {
                    Section("Error") {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Inputs")
        }
    }
}
