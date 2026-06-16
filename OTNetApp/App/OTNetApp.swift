import SwiftUI

@main
struct OTNetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settingsStore)
                .task { await settingsStore.load() }
        }
    }
}
