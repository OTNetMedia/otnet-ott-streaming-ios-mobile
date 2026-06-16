import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OTNetTheme.rowGap) {
                #if DEBUG
                DebugBar(rowCount: vm.rowCount, itemCount: vm.itemCount, lastError: vm.lastError)
                #endif

                switch vm.phase {
                case .loading:
                    StatePlaceholder(mode: .loading).frame(height: 400)
                case .empty:
                    StatePlaceholder(mode: .empty("No content yet. Add some in the dashboard."))
                        .frame(height: 400)
                case .failed(let err):
                    StatePlaceholder(
                        mode: .error(err.localizedDescription, retry: { Task { await vm.load() } })
                    ).frame(height: 400)
                case .loaded(let homepage):
                    if let hero = homepage.hero, !hero.isEmpty {
                        HeroBanner(items: hero)
                            .ignoresSafeArea(edges: .top)
                    }
                    ForEach(homepage.rows ?? []) { row in
                        ContentRow(row: row)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topTrailing) {
            NavigationLink(value: SearchRoute()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.55), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .navigationDestination(for: Genre.self) { CategoryDetailView(category: $0) }
        .navigationDestination(for: SearchRoute.self) { _ in SearchView() }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}
