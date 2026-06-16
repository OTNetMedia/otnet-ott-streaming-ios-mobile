import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var phase: Phase<HomepageResponse> = .loading
    @Published var lastError: String?

    var rowCount: Int {
        if case .loaded(let h) = phase { return h.rows?.count ?? 0 }
        return 0
    }

    var itemCount: Int {
        if case .loaded(let h) = phase {
            return (h.rows ?? []).reduce(0) { $0 + ($1.items?.count ?? 0) } + (h.hero?.count ?? 0)
        }
        return 0
    }

    func load() async {
        phase = .loading
        lastError = nil
        do {
            let h = try await OTNetAPI.shared.homepage()
            let hasContent = (h.hero?.isEmpty == false) ||
                (h.rows?.contains(where: { ($0.items?.count ?? 0) > 0 }) ?? false)
            phase = hasContent ? .loaded(h) : .empty
        } catch {
            lastError = String(describing: error)
            phase = .failed(error)
        }
    }
}
