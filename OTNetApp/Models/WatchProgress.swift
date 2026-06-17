import Foundation

/// One row from `GET /telemetry/progress`. We tolerate a few field-name
/// variants the publisher API may emit (position vs positionSec, etc.).
struct WatchProgress: Decodable, Identifiable, Hashable {
    let id: String
    let contentId: String?
    let position: Double
    let duration: Double
    let completed: Bool?
    let updatedAt: String?
    let profileIndex: Int?
    let content: Content?

    enum CodingKeys: String, CodingKey {
        case _id, contentId
        case position, positionSec, positionSeconds, progressSeconds
        case duration, durationSec, durationSeconds
        case completed, updatedAt, profileIndex
        case content
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // The /telemetry/progress endpoint flattens the Content payload into
        // each item — `_id` IS the content's `_id`, not a separate progress id.
        let underscoreId = try c.decodeIfPresent(String.self, forKey: ._id)
        let cidExplicit = try c.decodeIfPresent(String.self, forKey: .contentId)
        let updated = try c.decodeIfPresent(String.self, forKey: .updatedAt)

        let cid = cidExplicit ?? underscoreId
        self.contentId = cid
        self.id = underscoreId ?? "\(cid ?? "no-id")-\(updated ?? UUID().uuidString)"

        // Position / duration accept multiple key forms; default to 0.
        self.position = WatchProgress.firstDouble(
            container: c,
            keys: [.position, .positionSec, .positionSeconds, .progressSeconds]
        )
        self.duration = WatchProgress.firstDouble(
            container: c,
            keys: [.duration, .durationSec, .durationSeconds]
        )

        self.completed = try c.decodeIfPresent(Bool.self, forKey: .completed)
        self.updatedAt = updated
        self.profileIndex = try c.decodeIfPresent(Int.self, forKey: .profileIndex)

        // Prefer an explicit `content` object if the server sends one; otherwise
        // decode the same root container as a Content (the item is a flattened
        // Content with `progressSeconds`/`durationSeconds`/`mediaIndex` added).
        if let embedded = try c.decodeIfPresent(Content.self, forKey: .content) {
            self.content = embedded
        } else {
            self.content = try? Content(from: decoder)
        }
    }

    var fractionComplete: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, position / duration))
    }

    /// The catalog content to render. Use embedded payload when present,
    /// otherwise we'll need to look it up by ID.
    var displayContent: Content? { content }

    private static func firstDouble(
        container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Double {
        for key in keys {
            if let v = try? container.decodeIfPresent(Double.self, forKey: key) { return v }
            if let v = try? container.decodeIfPresent(Int.self, forKey: key) { return Double(v) }
        }
        return 0
    }
}

struct WatchProgressResponse: Decodable {
    let items: [WatchProgress]?
}
