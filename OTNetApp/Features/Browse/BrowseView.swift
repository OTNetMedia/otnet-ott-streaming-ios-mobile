import SwiftUI

struct BrowseView: View {
    @StateObject private var vm = BrowseViewModel()

    var body: some View {
        Group {
            switch vm.phase {
            case .loading:
                StatePlaceholder(mode: .loading)
            case .empty:
                StatePlaceholder(mode: .empty("No categories yet."))
            case .failed(let e):
                StatePlaceholder(
                    mode: .error(e.localizedDescription, retry: { Task { await vm.load() } })
                )
            case .loaded(let cats):
                List(cats) { cat in
                    NavigationLink(value: cat) {
                        HStack {
                            Text(cat.name ?? "Untitled")
                                .foregroundStyle(OTNetTheme.textPrimary)
                            Spacer()
                            if let kids = cat.children, !kids.isEmpty {
                                Text("\(kids.count)")
                                    .foregroundStyle(OTNetTheme.textTertiary)
                                    .font(.caption)
                            }
                        }
                    }
                    .listRowBackground(OTNetTheme.card)
                }
                .scrollContentBackground(.hidden)
                .background(OTNetTheme.background)
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle("Browse")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: SearchRoute()) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OTNetTheme.textPrimary)
                }
            }
        }
        .navigationDestination(for: Genre.self) { CategoryDetailView(category: $0) }
        .navigationDestination(for: SearchRoute.self) { _ in SearchView() }
        .task { await vm.load() }
    }
}

struct SearchRoute: Hashable {}
