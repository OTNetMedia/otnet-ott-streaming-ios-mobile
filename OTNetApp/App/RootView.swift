import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var authStore: AuthStore

    private var s: PublisherSettings? { settingsStore.settings }
    private var epgEnabled: Bool { s?.epgEnabled ?? true }
    private var myListEnabled: Bool { s?.myListEnabled ?? true }
    private var myListShowInNav: Bool { s?.myListShowInNav ?? true }
    private var viewerAuthNone: Bool { s?.viewerAuthNone ?? false }
    private var requireAuth: Bool { !viewerAuthNone }

    var body: some View {
        ZStack {
            tabs
                .opacity(showingGate ? 0 : 1)
                .allowsHitTesting(!showingGate)

            if showingGate {
                AuthGateView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingGate)
        .preferredColorScheme(.dark)
    }

    private var showingGate: Bool {
        // Don't gate until settings have loaded so we don't briefly flash the
        // login screen for publishers running in viewerAuthMode "none".
        settingsStore.isLoaded && requireAuth && !authStore.isSignedIn
    }

    private var tabs: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { BrowseView() }
                .tabItem { Label("Browse", systemImage: "square.grid.2x2.fill") }

            if epgEnabled {
                NavigationStack { LiveTVView() }
                    .tabItem { Label("Live TV", systemImage: "tv.fill") }
            }

            if myListEnabled && myListShowInNav && !viewerAuthNone {
                NavigationStack { MyListView() }
                    .tabItem { Label("My List", systemImage: "heart.fill") }
            }
        }
        .tint(OTNetTheme.primary)
    }
}
