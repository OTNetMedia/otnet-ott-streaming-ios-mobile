import SwiftUI

@main
struct OTNetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var authStore = AuthStore()
    @StateObject private var myListStore = MyListStore()
    @StateObject private var continueWatchingStore = ContinueWatchingStore()

    init() {
        // Generous shared HTTP cache so the underlying URLSession returns
        // posters and backdrops from disk on subsequent scrolls.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 300 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settingsStore)
                .environmentObject(authStore)
                .environmentObject(myListStore)
                .environmentObject(continueWatchingStore)
                .task {
                    await authStore.restore()
                    await settingsStore.load()
                    if authStore.isSignedIn {
                        await myListStore.refresh(profileIndex: authStore.activeProfileIndex)
                        await continueWatchingStore.refresh(profileIndex: authStore.activeProfileIndex)
                    }
                }
                .onChange(of: authStore.isSignedIn) { signedIn in
                    if signedIn {
                        Task {
                            await myListStore.refresh(profileIndex: authStore.activeProfileIndex)
                            await continueWatchingStore.refresh(profileIndex: authStore.activeProfileIndex)
                        }
                    } else {
                        myListStore.clear()
                        continueWatchingStore.clear()
                    }
                }
                .onChange(of: authStore.activeProfileIndex) { idx in
                    guard authStore.isSignedIn else { return }
                    Task {
                        await myListStore.refresh(profileIndex: idx)
                        await continueWatchingStore.refresh(profileIndex: idx)
                    }
                }
        }
    }
}
