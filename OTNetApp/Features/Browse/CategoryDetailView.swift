import SwiftUI

struct CategoryDetailView: View {
    let category: Genre
    @StateObject private var vm = CategoryDetailViewModel()

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]

    var body: some View {
        Group {
            switch vm.phase {
            case .loading:
                StatePlaceholder(mode: .loading)
            case .empty:
                StatePlaceholder(mode: .empty("No titles in \(category.name ?? "this category")."))
            case .failed(let e):
                StatePlaceholder(
                    mode: .error(e.localizedDescription, retry: { Task { await vm.load(category.id) } })
                )
            case .loaded(let items):
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                PosterCard(
                                    url: item.posterURL,
                                    title: item.displayTitle,
                                    ageRating: item.ageRating
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle(category.name ?? "Category")
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .task { await vm.load(category.id) }
    }
}

@MainActor
final class CategoryDetailViewModel: ObservableObject {
    @Published var phase: Phase<[Content]> = .loading

    func load(_ categoryId: String) async {
        phase = .loading
        do {
            let page = try await OTNetAPI.shared.contentByCategory(categoryId)
            let items = page.items ?? []
            phase = items.isEmpty ? .empty : .loaded(items)
        } catch {
            phase = .failed(error)
        }
    }
}
