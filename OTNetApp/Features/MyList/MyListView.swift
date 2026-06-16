import SwiftUI

struct MyListView: View {
    @StateObject private var vm = MyListViewModel()
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]

    var body: some View {
        Group {
            switch vm.phase {
            case .loading:
                StatePlaceholder(mode: .loading)
            case .empty:
                StatePlaceholder(mode: .empty("Sign in and add titles by tapping the heart on a content page."))
            case .failed(let e):
                StatePlaceholder(
                    mode: .error(e.localizedDescription, retry: { Task { await vm.load() } })
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
        .navigationTitle("My List")
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .task { await vm.load() }
    }
}

@MainActor
final class MyListViewModel: ObservableObject {
    @Published var phase: Phase<[Content]> = .loading

    func load() async {
        phase = .loading
        struct Page: Decodable { let items: [Content]? }
        do {
            let page: Page = try await OTNetAPI.shared.get(
                "/viewer/list",
                query: [URLQueryItem(name: "profileIndex", value: "0")]
            )
            let items = page.items ?? []
            phase = items.isEmpty ? .empty : .loaded(items)
        } catch {
            phase = .failed(error)
        }
    }
}
