import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var settings: PublisherSettings?
    @Published private(set) var isLoaded = false

    func load() async {
        do {
            settings = try await OTNetAPI.shared.settings()
        } catch {
            DebugProbe.log("settings load failed: \(error)")
            settings = nil
        }
        isLoaded = true
    }
}
