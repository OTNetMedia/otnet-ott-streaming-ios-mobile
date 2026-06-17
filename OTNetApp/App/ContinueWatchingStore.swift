import Foundation

@MainActor
final class ContinueWatchingStore: ObservableObject {
    @Published private(set) var items: [WatchProgress] = []
    @Published private(set) var contentById: [String: Content] = [:]
    @Published private(set) var isLoading = false

    func refresh(profileIndex: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await OTNetAPI.shared.watchProgress(profileIndex: profileIndex)
            let loaded = resp.items ?? []
            items = loaded
            DebugProbe.log("continue-watching loaded \(loaded.count) items for profileIndex=\(profileIndex)")

            // Seed cache with any embedded Content payloads.
            var cache = contentById
            for p in loaded {
                if let c = p.content { cache[c.id] = c }
            }
            // Fetch missing content payloads in parallel.
            let missingIds = loaded.compactMap { p -> String? in
                guard let cid = p.contentId, cache[cid] == nil else { return nil }
                return cid
            }
            if !missingIds.isEmpty {
                DebugProbe.log("continue-watching hydrating \(missingIds.count) content ids")
                let fetched: [(String, Content)] = await withTaskGroup(
                    of: Optional<(String, Content)>.self,
                    returning: [(String, Content)].self
                ) { group in
                    for cid in missingIds {
                        group.addTask {
                            do {
                                let c = try await OTNetAPI.shared.content(id: cid)
                                return (cid, c)
                            } catch {
                                DebugProbe.log("continue-watching hydrate failed for \(cid): \(error.localizedDescription)")
                                return nil
                            }
                        }
                    }
                    var results: [(String, Content)] = []
                    for await pair in group {
                        if let pair { results.append(pair) }
                    }
                    return results
                }
                for (cid, c) in fetched { cache[cid] = c }
            }
            contentById = cache
        } catch {
            // Don't clear the cache on transient errors / cancellations.
            if (error as NSError).code == NSURLErrorCancelled { return }
            DebugProbe.log("continue-watching load failed: \(error)")
        }
    }

    func content(for progress: WatchProgress) -> Content? {
        if let embedded = progress.content { return embedded }
        if let cid = progress.contentId { return contentById[cid] }
        return nil
    }

    func clear() {
        items = []
        contentById = [:]
    }
}
