import SwiftUI

@main
struct OTNetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var authStore = AuthStore()
    @StateObject private var myListStore = MyListStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settingsStore)
                .environmentObject(authStore)
                .environmentObject(myListStore)
                .task {
                    await authStore.restore()
                    await settingsStore.load()
                    if authStore.isSignedIn {
                        await myListStore.refresh(profileIndex: authStore.activeProfileIndex)
                    }
                }
                .onChange(of: authStore.isSignedIn) { signedIn in
                    if signedIn {
                        Task { await myListStore.refresh(profileIndex: authStore.activeProfileIndex) }
                    } else {
                        myListStore.clear()
                    }
                }
                .onChange(of: authStore.activeProfileIndex) { idx in
                    guard authStore.isSignedIn else { return }
                    Task { await myListStore.refresh(profileIndex: idx) }
                }
        }
    }
}
