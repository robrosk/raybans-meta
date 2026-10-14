import SwiftUI

struct ContentView: View {
    @EnvironmentObject var wearables: WearablesService

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Button("Connect glasses") { wearables.register() }
                    .buttonStyle(.borderedProminent)
                Button("Start session") { wearables.startSession() }
                    .buttonStyle(.bordered)
                Button("Snap photo") { wearables.capturePhoto() }
                    .buttonStyle(.bordered)
                    .disabled(!wearables.sessionActive)

                List(wearables.entries) { entry in
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                }
            }
            .padding()
            .navigationTitle("Snap Journal")
        }
    }
}
