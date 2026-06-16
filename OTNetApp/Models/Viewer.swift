import Foundation

struct Viewer: Codable, Hashable, Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    let profiles: [ViewerProfile]?
}

struct ViewerProfile: Codable, Hashable, Identifiable {
    var id: String { _id ?? UUID().uuidString }
    let _id: String?
    let name: String?
    let avatar: String?
    let maxRating: String?
    let kids: Bool?

    var displayName: String { name?.nilIfEmpty ?? "Profile" }
    var initial: String { String(displayName.prefix(1)).uppercased() }
    var avatarURL: URL? {
        guard let s = avatar?.nilIfEmpty else { return nil }
        return URL(string: s)
    }
}

struct ProfilesResponse: Codable {
    let profiles: [ViewerProfile]?
}

struct AuthResponse: Codable {
    let viewer: Viewer?
    let accessToken: String?
    let refreshToken: String?
}

struct RefreshResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
