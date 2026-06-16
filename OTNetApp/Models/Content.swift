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
    let date: String?
    let primaryGroup: GroupRef?
    let secondaryGroup: GroupRef?
    let organization: GroupRef?
    let metadata: [MetadataItem]?
    let personnel: [Personnel]?
    let contentAdvisory: [String]?
    let venue: String?

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
    var studioName: String? {
        [primaryGroup?.name, organization?.name]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }
    var year: String? {
        guard let date, date.count >= 4 else { return nil }
        let prefix = String(date.prefix(4))
        return Int(prefix) != nil ? prefix : nil
    }
    var ratingValue: String? {
        metadata?.first { $0.key?.caseInsensitiveCompare("Rating") == .orderedSame }?.value
    }
    var monetizationLabel: String? {
        guard let mode = monetization?.mode, !mode.isEmpty else { return nil }
        switch mode.lowercased() {
        case "free": return "Free"
        case "ppv": return "PPV"
        case "rental": return "Rental"
        case "subscription", "svod": return "Subscription"
        case "ads", "avod": return "Ad-supported"
        default: return mode.capitalized
        }
    }
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, description, contentType, type, media, ageRating, titleImage
        case childCount, sortOrder, parent, genres
        case entitled, paywall, monetization
        case date, primaryGroup, secondaryGroup, organization, metadata
        case personnel, contentAdvisory, venue
    }
}

extension Content: Hashable {
    static func == (lhs: Content, rhs: Content) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ContentParentRef: Codable, Hashable {
    let id: String?

    enum CodingKeys: String, CodingKey { case id = "_id" }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            self.id = single
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
    }
}

struct GroupRef: Codable, Hashable {
    let id: String?
    let name: String?
    let logo: String?
    enum CodingKeys: String, CodingKey { case id = "_id", name, logo }
}

struct MetadataItem: Codable, Hashable {
    let key: String?
    let value: String?
}

struct Personnel: Codable, Hashable, Identifiable {
    let id: String?
    let role: String?
    let person: PersonRef?

    var displayName: String? { person?.name }
    var headshotURL: URL? { person?.headshot.flatMap(URL.init(string:)) }

    enum CodingKeys: String, CodingKey { case id = "_id", role, person }
}

struct PersonProfile: Codable, Hashable {
    let id: String?
    let name: String?
    let title: String?
    let headshot: String?
    let team: GroupRef?
    let organization: GroupRef?

    enum CodingKeys: String, CodingKey {
        case id = "_id", name, title, headshot, team, organization
    }

    var headshotURL: URL? { headshot.flatMap(URL.init(string:)) }
}

struct PersonRef: Codable, Hashable {
    let id: String?
    let name: String?
    let title: String?
    let headshot: String?

    enum CodingKeys: String, CodingKey { case id = "_id", name, title, headshot }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            self.id = single
            self.name = nil
            self.title = nil
            self.headshot = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.headshot = try c.decodeIfPresent(String.self, forKey: .headshot)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(headshot, forKey: .headshot)
    }
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
    let title: String?
    let overview: String?
    let language: String?
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
