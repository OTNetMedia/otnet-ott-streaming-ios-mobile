import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var viewer: Viewer?
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?
    @Published private(set) var profiles: [ViewerProfile] = []
    @Published private(set) var activeProfileIndex: Int = 0

    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    private enum Key {
        static let access = "viewer_access_token"
        static let refresh = "viewer_refresh_token"
        static let viewer = "viewer_payload"
    }

    private let activeProfileDefaultsKey = "viewer_active_profile_index"

    var activeProfile: ViewerProfile? {
        guard !profiles.isEmpty else { return nil }
        let idx = max(0, min(activeProfileIndex, profiles.count - 1))
        return profiles[idx]
    }

    var profileLimit: Int { 5 }

    init() {
        activeProfileIndex = UserDefaults.standard.integer(forKey: activeProfileDefaultsKey)
    }

    func setActiveProfile(index: Int) {
        guard index >= 0, index < profiles.count else { return }
        activeProfileIndex = index
        UserDefaults.standard.set(index, forKey: activeProfileDefaultsKey)
    }

    func refreshProfiles() async {
        do {
            let resp = try await OTNetAPI.shared.profiles()
            profiles = resp.profiles ?? []
            if activeProfileIndex >= profiles.count {
                setActiveProfile(index: 0)
            }
        } catch {
            DebugProbe.log("profiles load failed: \(error)")
        }
    }

    func createProfile(name: String, avatar: String?, kids: Bool) async -> Bool {
        do {
            let resp = try await OTNetAPI.shared.createProfile(name: name, avatar: avatar, kids: kids)
            profiles = resp.profiles ?? profiles
            return true
        } catch {
            lastError = friendlyError(error)
            return false
        }
    }

    func updateProfile(index: Int, name: String?, avatar: String?, kids: Bool?) async -> Bool {
        do {
            let resp = try await OTNetAPI.shared.updateProfile(index: index, name: name, avatar: avatar, kids: kids)
            profiles = resp.profiles ?? profiles
            return true
        } catch {
            lastError = friendlyError(error)
            return false
        }
    }

    func deleteProfile(index: Int) async -> Bool {
        do {
            let resp = try await OTNetAPI.shared.deleteProfile(index: index)
            profiles = resp.profiles ?? profiles
            if activeProfileIndex >= profiles.count { setActiveProfile(index: 0) }
            return true
        } catch {
            lastError = friendlyError(error)
            return false
        }
    }

    /// Restore session from Keychain on app launch. If the access token has
    /// expired but the refresh token is still valid, mint a new access token.
    func restore() async {
        let cachedAccess = KeychainStore.get(Key.access)
        let cachedRefresh = KeychainStore.get(Key.refresh)
        if let data = KeychainStore.get(Key.viewer)?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(Viewer.self, from: data) {
            viewer = decoded
        }
        accessToken = cachedAccess
        refreshToken = cachedRefresh

        if let token = cachedAccess, !isExpired(jwt: token) {
            isSignedIn = true
            await OTNetAPI.shared.setViewerToken(token)
            await refreshProfiles()
        } else if let refreshTok = cachedRefresh {
            await refresh(using: refreshTok)
        }
    }

    func login(email: String, password: String) async {
        await perform {
            try await OTNetAPI.shared.login(email: email, password: password)
        }
    }

    func register(email: String, password: String, displayName: String) async {
        await perform {
            try await OTNetAPI.shared.register(email: email, password: password, displayName: displayName)
        }
    }

    func logout() async {
        await OTNetAPI.shared.logout()
        await OTNetAPI.shared.setViewerToken(nil)
        accessToken = nil
        refreshToken = nil
        viewer = nil
        profiles = []
        activeProfileIndex = 0
        UserDefaults.standard.removeObject(forKey: activeProfileDefaultsKey)
        isSignedIn = false
        KeychainStore.remove(Key.access)
        KeychainStore.remove(Key.refresh)
        KeychainStore.remove(Key.viewer)
    }

    // MARK: - Private

    private func perform(_ call: () async throws -> AuthResponse) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let resp = try await call()
            await applyAuth(resp)
        } catch {
            lastError = friendlyError(error)
        }
    }

    private func applyAuth(_ resp: AuthResponse) async {
        guard let access = resp.accessToken else {
            lastError = "Server did not return an access token."
            return
        }
        accessToken = access
        refreshToken = resp.refreshToken ?? refreshToken
        viewer = resp.viewer
        if let initial = resp.viewer?.profiles { profiles = initial }
        isSignedIn = true

        KeychainStore.set(access, for: Key.access)
        if let r = resp.refreshToken { KeychainStore.set(r, for: Key.refresh) }
        if let v = resp.viewer, let data = try? JSONEncoder().encode(v) {
            KeychainStore.set(String(data: data, encoding: .utf8), for: Key.viewer)
        }
        await OTNetAPI.shared.setViewerToken(access)
        await refreshProfiles()
    }

    private func refresh(using token: String) async {
        do {
            let resp = try await OTNetAPI.shared.refreshAuth(refreshToken: token)
            if let access = resp.accessToken {
                accessToken = access
                if let r = resp.refreshToken { refreshToken = r; KeychainStore.set(r, for: Key.refresh) }
                KeychainStore.set(access, for: Key.access)
                isSignedIn = true
                await OTNetAPI.shared.setViewerToken(access)
            } else {
                await logout()
            }
        } catch {
            DebugProbe.log("refresh failed: \(error)")
            await logout()
        }
    }

    private func isExpired(jwt: String) -> Bool {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3, let payloadData = base64UrlDecode(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? Double
        else { return true }
        // Leave 30s of leeway so we refresh just before the server boundary.
        return Date(timeIntervalSince1970: exp).timeIntervalSinceNow < 30
    }

    private func base64UrlDecode(_ str: String) -> Data? {
        var s = str.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (s.count % 4)
        if padding != 4 { s += String(repeating: "=", count: padding) }
        return Data(base64Encoded: s)
    }

    private func friendlyError(_ error: Error) -> String {
        if case let APIError.http(status) = error {
            switch status {
            case 400, 422: return "Please check your details and try again."
            case 401:      return "Email or password is incorrect."
            case 409:      return "That email is already in use."
            case 429:      return "Too many attempts — please wait a moment."
            case 500...:   return "OTNet is having trouble — please try again."
            default:       return "Sign-in failed (HTTP \(status))."
            }
        }
        return error.localizedDescription
    }
}
