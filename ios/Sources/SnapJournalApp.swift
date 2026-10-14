import SwiftUI

@main
struct SnapJournalApp: App {
    @StateObject private var wearables = WearablesService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wearables)
        }
    }
}
