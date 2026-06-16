import Foundation

@MainActor
final class BrowseViewModel: ObservableObject {
    @Published var phase: Phase<[Genre]> = .loading

    func load() async {
        phase = .loading
        do {
            let cats = try await OTNetAPI.shared.categoriesTree()
            phase = cats.isEmpty ? .empty : .loaded(cats)
        } catch {
            phase = .failed(error)
        }
    }
}
