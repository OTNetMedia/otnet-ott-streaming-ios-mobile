import SwiftUI
import UIKit

/// Drop-in replacement for SwiftUI's `AsyncImage` that caches decoded images
/// in memory (NSCache) and reuses HTTP responses through `URLCache.shared`.
/// AsyncImage re-fetches on every appear, which is bad for a scrollable feed.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let transaction: Transaction
    let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.transaction = transaction
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }
        if let cached = ImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }
        do {
            let req = URLRequest(
                url: url,
                cachePolicy: .returnCacheDataElseLoad,
                timeoutInterval: 30
            )
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let img = UIImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }
            ImageCache.shared.set(img, for: url)
            withTransaction(transaction) {
                phase = .success(Image(uiImage: img))
            }
        } catch {
            if Task.isCancelled { return }
            phase = .failure(error)
        }
    }
}

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private var inflight: Set<URL> = []
    private let inflightLock = NSLock()

    private init() {
        cache.countLimit = 400
        cache.totalCostLimit = 120 * 1024 * 1024 // ~120 MB of decoded pixels
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        cache.setObject(image, forKey: url as NSURL, cost: max(cost, 1))
    }

    func clear() {
        cache.removeAllObjects()
    }

    /// Warm the cache for the given URLs. Skips anything already cached or
    /// already being fetched. Fire-and-forget — callers don't await results.
    func prefetch(_ urls: [URL?]) {
        let unique = Set(urls.compactMap { $0 })
        for url in unique {
            if image(for: url) != nil { continue }
            inflightLock.lock()
            let alreadyInflight = inflight.contains(url)
            if !alreadyInflight { inflight.insert(url) }
            inflightLock.unlock()
            guard !alreadyInflight else { continue }

            Task.detached(priority: .utility) { [weak self] in
                defer {
                    self?.inflightLock.lock()
                    self?.inflight.remove(url)
                    self?.inflightLock.unlock()
                }
                let req = URLRequest(url: url,
                                     cachePolicy: .returnCacheDataElseLoad,
                                     timeoutInterval: 30)
                guard let (data, _) = try? await URLSession.shared.data(for: req),
                      let img = UIImage(data: data) else { return }
                await MainActor.run { self?.set(img, for: url) }
            }
        }
    }
}
