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

            // Seed cache with the embedded slim payloads so titles render
            // immediately. The /telemetry/progress shape lacks top-level
            // artwork URLs, so we then re-fetch every item from
            // /catalog/content/:id and overwrite the cache with the full
            // Content payload — that's the one that has portrait/landscape/
            // backdrop URLs the tile actually displays.
            var cache = contentById
            for p in loaded {
                if let c = p.content { cache[c.id] = c }
            }
            contentById = cache

            let allIds = loaded.compactMap { $0.contentId }
            guard !allIds.isEmpty else { return }
            DebugProbe.log("continue-watching hydrating \(allIds.count) content ids")
            let fetched: [(String, Content)] = await withTaskGroup(
                of: Optional<(String, Content)>.self,
                returning: [(String, Content)].self
            ) { group in
                for cid in allIds {
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
            if !fetched.isEmpty {
                var hydrated = contentById
                for (cid, c) in fetched { hydrated[cid] = c }
                contentById = hydrated
            }
        } catch {
            // Don't clear the cache on transient errors / cancellations.
            if (error as NSError).code == NSURLErrorCancelled { return }
            DebugProbe.log("continue-watching load failed: \(error)")
        }
    }

    /// Prefer the hydrated catalog payload (has artwork URLs) over the slim
    /// payload embedded in the /telemetry/progress response (title only).
    func content(for progress: WatchProgress) -> Content? {
        if let cid = progress.contentId, let cached = contentById[cid] { return cached }
        return progress.content
    }

    func clear() {
        items = []
        contentById = [:]
    }
}
