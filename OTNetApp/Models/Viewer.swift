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

/// Returned by POST /viewer/profiles/select on success. The accessToken /
/// refreshToken are profile-bound — store these and use them for every
/// subsequent API call.
struct ProfileSelectResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let profileIndex: Int?
    let profile: ViewerProfile?
}

/// Typed errors surfaced from POST /viewer/profiles/select.
enum ProfileSelectError: Error, Equatable {
    case pinRequired
    case pinIncorrect(attemptsRemaining: Int?)
    case pinLocked(retryAfterMs: Int?, retryAt: Date?)
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
