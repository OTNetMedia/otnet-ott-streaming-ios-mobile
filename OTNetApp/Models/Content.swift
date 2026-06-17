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
    /// Top-level portrait artwork (preferred over media[0].portrait).
    let portrait: String?
    /// Top-level landscape artwork (preferred over media[0].landscape).
    let landscape: String?
    /// Top-level backdrop artwork (preferred over media[0].backdrop).
    let backdrop: String?
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
    /// Teaser preview, multi-protocol so iOS / Apple TV grab HLS while
    /// other clients take whichever they prefer. nil = no teaser set.
    let teaser: TeaserInfo?

    var displayTitle: String { title ?? "Untitled" }
    var firstMedia: MediaItem? { media?.first }
    var titleImageURL: URL? { titleImage.flatMap(URL.init(string:)) }

    /// Portrait/tile artwork. Prefers the top-level `portrait`, then other
    /// top-level images, and finally falls back to the first media item.
    var posterURL: URL? {
        Content.firstURL(
            portrait, titleImage, landscape, backdrop,
            firstMedia?.portrait, firstMedia?.landscape, firstMedia?.backdrop
        )
    }

    /// Landscape artwork (banners, hero, content rows).
    var landscapeURL: URL? {
        Content.firstURL(
            landscape, backdrop, titleImage, portrait,
            firstMedia?.landscape, firstMedia?.backdrop, firstMedia?.portrait
        )
    }

    /// Wide backdrop (detail-page hero). Prefers backdrop over landscape.
    var backdropURL: URL? {
        Content.firstURL(
            backdrop, landscape, titleImage, portrait,
            firstMedia?.backdrop, firstMedia?.landscape, firstMedia?.portrait
        )
    }

    private static func firstURL(_ candidates: String?...) -> URL? {
        for s in candidates {
            if let s, !s.isEmpty, let url = URL(string: s) { return url }
        }
        return nil
    }
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
        case portrait, landscape, backdrop
        case childCount, sortOrder, parent, genres
        case entitled, paywall, monetization
        case date, primaryGroup, secondaryGroup, organization, metadata
        case personnel, contentAdvisory, venue, teaser
    }

    /// AVPlayer-compatible teaser URL. Pulls the HLS variant out of the
    /// structured teaser block — DASH (.mpd) cannot play natively on iOS,
    /// so we explicitly require a `protocol == "hls"` variant. Returns nil
    /// when none is set, the .m3u8 surface, the tile renders without an
    /// inline preview.
    var teaserHLSURL: URL? {
        guard let variants = teaser?.variants,
              let entry = variants.first(where: { $0.protocolName?.lowercased() == "hls" })?.entrypoint,
              let url = URL(string: entry) else { return nil }
        return url
    }

    /// Poster image baked into the teaser ingest (encoder's master.jpg
    /// pulled from the middle of the clip). Useful as a still
    /// placeholder before the teaser starts streaming.
    var teaserPosterURL: URL? {
        guard let s = teaser?.resources?.poster, let url = URL(string: s) else { return nil }
        return url
    }
}

/// Structured teaser block. Variants mirror the media[i] shape so any
/// future protocol drops in without another model change. Resources +
/// duration come straight from the encoder's asset-level outputs.
struct TeaserInfo: Codable, Hashable {
    let variants: [TeaserVariant]?
    let duration: Int?
    let resources: TeaserResources?

    enum CodingKeys: String, CodingKey { case variants, duration, resources }

    init(variants: [TeaserVariant]? = nil, duration: Int? = nil, resources: TeaserResources? = nil) {
        self.variants = variants
        self.duration = duration
        self.resources = resources
    }

    init(from decoder: Decoder) throws {
        // Legacy content rows in /viewer/list still come back with `teaser: ""`
        // (a string) instead of the structured object. Treat any non-object
        // shape as "no teaser configured" so a single legacy row can't blow up
        // decoding of the whole response.
        if let single = try? decoder.singleValueContainer(),
           (try? single.decode(String.self)) != nil
            || (try? single.decode(Int.self)) != nil
            || (try? single.decode(Double.self)) != nil
            || (try? single.decode(Bool.self)) != nil {
            self.variants = nil
            self.duration = nil
            self.resources = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.variants  = try c.decodeIfPresent([TeaserVariant].self, forKey: .variants)
        self.duration  = try c.decodeIfPresent(Int.self,             forKey: .duration)
        self.resources = try c.decodeIfPresent(TeaserResources.self, forKey: .resources)
    }
}

struct TeaserVariant: Codable, Hashable {
    let protocolName: String?
    let entrypoint: String?

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case entrypoint
    }
}

struct TeaserResources: Codable, Hashable {
    let poster: String?
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

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            self.id = single
            self.name = nil
            self.logo = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.logo = try c.decodeIfPresent(String.self, forKey: .logo)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(logo, forKey: .logo)
    }
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
