import SwiftUI

struct RootView: View {
    let epgEnabled: Bool
    let myListEnabled: Bool
    let viewerAuthNone: Bool

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

            if myListEnabled && !viewerAuthNone {
                NavigationStack { MyListView() }
                    .tabItem { Label("My List", systemImage: "heart.fill") }
            }
        }
        .tint(OTNetTheme.primary)
        .preferredColorScheme(.dark)
    }
}
