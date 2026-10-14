import Foundation

// TODO: import MWDATCore / MWDATCamera once the SwiftPM dependency is added in Xcode.
// Reference implementation: https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples
// Guide: https://wearables.developer.meta.com/docs/develop/dat/build-integration-ios/

struct JournalEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    // TODO: let photoData: Data — JPEG returned by capturePhoto(), persisted by JournalStore.
}

@MainActor
final class WearablesService: ObservableObject {
    @Published var sessionActive = false
    @Published var entries: [JournalEntry] = []

    func register() {
        // TODO: Wearables.configure() using Info.plist keys (MetaAppID, ClientToken,
        // TeamID, AppLinkURLScheme), then the one-time registration flow.
        // The Meta AI app handles confirmation via deeplink and returns to us.
    }

    func startSession() {
        // TODO: createSession() -> session.start() -> addCamera() -> stream starts.
        // NOTE: photo capture requires an ACTIVE camera stream — start it first.
    }

    func capturePhoto() {
        // TODO: capture a single frame during the stream, append a JournalEntry,
        // and persist the JPEG (see JournalStore).
    }
}
