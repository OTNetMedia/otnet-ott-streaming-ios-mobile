import Foundation

struct Content: Codable, Identifiable {
    let id: String
    let title: String?
    let description: String?
    let contentType: String?
    let type: String?
    let media: [MediaItem]?
    let ageRating: String?
    let titleImage: String?
    let childCount: Int?
    let sortOrder: Int?
    let parent: ContentParentRef?
    let genres: [GenreRef]?
    let entitled: Bool?
    let paywall: PaywallInfo?
    let monetization: MonetizationInfo?

    var displayTitle: String { title ?? "Untitled" }
    var firstMedia: MediaItem? { media?.first }
    var posterURL: URL? { firstMedia?.portrait.flatMap(URL.init(string:)) }
    var landscapeURL: URL? {
        (firstMedia?.landscape ?? firstMedia?.backdrop).flatMap(URL.init(string:))
    }
    var titleImageURL: URL? { titleImage.flatMap(URL.init(string:)) }
    var effectiveType: String { contentType ?? type ?? "movie" }
    var isSeries: Bool { (effectiveType == "series") || (childCount ?? 0) > 0 }
    var isSeason: Bool { effectiveType == "season" }
    var primaryGenreName: String? { genres?.first?.name }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, description, contentType, type, media, ageRating, titleImage
        case childCount, sortOrder, parent, genres
        case entitled, paywall, monetization
    }
}

extension Content: Hashable {
    static func == (lhs: Content, rhs: Content) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ContentParentRef: Codable {
    let id: String?
    enum CodingKeys: String, CodingKey { case id = "_id" }
}

struct PaywallInfo: Codable {
    let mode: String?
    let price: Double?
    let currency: String?
}

struct MonetizationInfo: Codable {
    let mode: String?
    let price: Double?
    let currency: String?
}

struct MediaItem: Codable {
    let portrait: String?
    let landscape: String?
    let backdrop: String?
    let variants: [MediaVariant]?
}

struct MediaVariant: Codable {
    let protocolName: String?
    let entrypoint: String?
    let duration: Int?
    let drm: DrmConfig?
    let resources: MediaResources?

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case entrypoint, duration, drm, resources
    }
}

struct MediaResources: Codable {
    let poster: String?
    let bif: String?
    let adbreaks: String?
}

struct DrmConfig: Codable {
    let sessionDrm: Bool?
    let provider: String?
    let widevine: DrmSystem?
    let playready: DrmSystem?
    let fairplay: DrmFairplay?
}

struct DrmSystem: Codable {
    let licenseUrl: String?
}

struct DrmFairplay: Codable {
    let licenseUrl: String?
    let certificateUrl: String?
}

struct DrmSessionResponse: Codable {
    let token: String
    let expiresIn: Int?
}
