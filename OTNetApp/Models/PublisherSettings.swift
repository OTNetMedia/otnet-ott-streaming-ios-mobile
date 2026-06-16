import Foundation

/// Mirror of the publisher's `/catalog/settings` document. Every field is
/// optional because the dashboard lets publishers turn modules off completely.
struct PublisherSettings: Decodable, Hashable {
    let ageRatings: AgeRatingsConfig?
    let pinProtection: ToggleConfig?
    let profileLimit: ProfileLimitConfig?
    let epg: EPGConfig?
    let errorReporting: ToggleConfig?
    let sessionDrm: ToggleConfig?
    let myList: MyListConfig?
    let adPolicy: AdPolicy?
    let branding: Branding?
    let debugOverlay: ToggleConfig?
    let viewerAuth: ViewerAuth?

    struct ToggleConfig: Decodable, Hashable {
        let enabled: Bool?
    }

    struct AgeRatingsConfig: Decodable, Hashable {
        let enabled: Bool?
        let ratingSystem: String?
        let ratings: [String]?
    }

    struct ProfileLimitConfig: Decodable, Hashable {
        let enabled: Bool?
        let max: Int?
    }

    struct EPGConfig: Decodable, Hashable {
        let enabled: Bool?
        let futureHours: Int?
        let pastMinutes: Int?
    }

    struct MyListConfig: Decodable, Hashable {
        let enabled: Bool?
        let showOnHomepage: Bool?
        let showInNav: Bool?
    }

    struct AdPolicy: Decodable, Hashable {
        let blockSkipping: Bool?
    }

    struct Branding: Decodable, Hashable {
        let name: String?
        let logo: String?
    }

    struct ViewerAuth: Decodable, Hashable {
        let mode: String?
        let externalUrl: String?
        let plans: [Plan]?

        struct Plan: Decodable, Hashable {
            let name: String?
            let stripePriceId: String?
            let amount: Int?
            let currency: String?
            let interval: String?
        }
    }

    // MARK: - Convenience accessors used across the app

    var epgEnabled: Bool { epg?.enabled ?? true }
    var myListEnabled: Bool { myList?.enabled ?? true }
    var myListShowInNav: Bool { myList?.showInNav ?? true }
    var myListShowOnHomepage: Bool { myList?.showOnHomepage ?? false }
    var viewerAuthMode: String { viewerAuth?.mode ?? "otnet" }
    var viewerAuthNone: Bool { viewerAuthMode == "none" }
    var blockAdSkipping: Bool { adPolicy?.blockSkipping ?? false }
    var brandName: String { branding?.name?.nilIfEmpty ?? "OTNet" }
    var ageRatingsEnabled: Bool { ageRatings?.enabled ?? false }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
