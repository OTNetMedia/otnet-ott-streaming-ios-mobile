import Foundation

struct ViewerListResponse: Decodable {
    let items: [Content]?
}

/// Caches the viewer's My List so the detail page can render the heart state
/// without a round-trip per content. Mutations optimistically update the cache
/// and roll back on failure.
@MainActor
final class MyListStore: ObservableObject {
    @Published private(set) var items: [Content] = []
    @Published private(set) var ids: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var pendingIds: Set<String> = []
    @Published var lastError: String?

    func contains(_ id: String) -> Bool { ids.contains(id) }
    func isPending(_ id: String) -> Bool { pendingIds.contains(id) }

    func refresh(profileIndex: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await OTNetAPI.shared.myList(profileIndex: profileIndex)
            let list = resp.items ?? []
            items = list
            ids = Set(list.map { $0.id })
        } catch {
            DebugProbe.log("my-list refresh failed: \(error)")
            lastError = error.localizedDescription
        }
    }

    func add(_ content: Content, profileIndex: Int) async {
        guard !ids.contains(content.id) else { return }
        pendingIds.insert(content.id)
        ids.insert(content.id)
        items.append(content)
        do {
            try await OTNetAPI.shared.addToList(contentId: content.id, profileIndex: profileIndex)
        } catch {
            ids.remove(content.id)
            items.removeAll { $0.id == content.id }
            lastError = error.localizedDescription
            DebugProbe.log("add to list failed: \(error)")
        }
        pendingIds.remove(content.id)
    }

    func remove(_ contentId: String, profileIndex: Int) async {
        guard ids.contains(contentId) else { return }
        let removed = items.first { $0.id == contentId }
        pendingIds.insert(contentId)
        ids.remove(contentId)
        items.removeAll { $0.id == contentId }
        do {
            try await OTNetAPI.shared.removeFromList(contentId: contentId, profileIndex: profileIndex)
        } catch {
            if let removed {
                items.append(removed)
                ids.insert(contentId)
            }
            lastError = error.localizedDescription
            DebugProbe.log("remove from list failed: \(error)")
        }
        pendingIds.remove(contentId)
    }

    func clear() {
        items = []
        ids = []
        pendingIds = []
        lastError = nil
    }
}
