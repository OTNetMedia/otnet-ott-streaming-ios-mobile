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
        .navigationDestination(for: Genre.self) { CategoryDetailView(category: $0) }
        .task { await vm.load() }
    }
}
