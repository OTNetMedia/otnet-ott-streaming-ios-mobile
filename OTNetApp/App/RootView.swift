import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    private var s: PublisherSettings? { settingsStore.settings }
    private var epgEnabled: Bool { s?.epgEnabled ?? true }
    private var myListEnabled: Bool { s?.myListEnabled ?? true }
    private var myListShowInNav: Bool { s?.myListShowInNav ?? true }
    private var viewerAuthNone: Bool { s?.viewerAuthNone ?? false }

    var body: some View {
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
        .preferredColorScheme(.dark)
    }
}
