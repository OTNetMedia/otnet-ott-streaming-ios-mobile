import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var viewer: Viewer?
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?
    @Published private(set) var profiles: [ViewerProfile] = []
    @Published private(set) var activeProfileIndex: Int = 0

    // PIN-gated profile switch state, observed by ProfilePickerView /
    // PinEntrySheet so the user can complete the parental-control check.
    @Published var pinPromptForIndex: Int?
    @Published var pinError: String?
    @Published var pinLockedUntil: Date?
    @Published var pinSwitchInFlight: Bool = false

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

    /// Switch the active profile. Asks the server to mint a profile-bound
    /// access token via /viewer/profiles/select; surfaces PIN state via the
    /// `pinPromptForIndex` / `pinError` / `pinLockedUntil` publishers so the
    /// UI can present a PIN entry sheet and call `submitProfilePin(_:)`.
    func setActiveProfile(index: Int) {
        guard index >= 0, index < profiles.count else { return }
        // Don't optimistically flip activeProfileIndex — the binding only
        // counts when the server hands back the new token. Otherwise a
        // failed PIN check would leave the UI showing the wrong profile.
        Task { await performProfileSelect(targetIndex: index, pin: nil) }
    }

    /// Continue a PIN-gated switch after the user types their 4-digit PIN.
    func submitProfilePin(_ pin: String) {
        guard let target = pinPromptForIndex else { return }
        Task { await performProfileSelect(targetIndex: target, pin: pin) }
    }

    /// Dismiss the PIN sheet without switching (user cancels).
    func cancelProfilePin() {
        pinPromptForIndex = nil
        pinError = nil
    }

    private func performProfileSelect(targetIndex: Int, pin: String?) async {
        pinSwitchInFlight = true
        defer { pinSwitchInFlight = false }
        do {
            let resp = try await OTNetAPI.shared.selectProfile(profileIndex: targetIndex, pin: pin)
            // Replace stored tokens with the profile-bound pair.
            if let access = resp.accessToken {
                accessToken = access
                KeychainStore.set(access, for: Key.access)
                await OTNetAPI.shared.setViewerToken(access)
            }
            if let refresh = resp.refreshToken {
                refreshToken = refresh
                KeychainStore.set(refresh, for: Key.refresh)
            }
            // Apply the (possibly server-clamped) profile index.
            let confirmed = resp.profileIndex ?? targetIndex
            activeProfileIndex = confirmed
            UserDefaults.standard.set(confirmed, forKey: activeProfileDefaultsKey)
            pinPromptForIndex = nil
            pinError = nil
            pinLockedUntil = nil
        } catch ProfileSelectError.pinRequired {
            pinPromptForIndex = targetIndex
            pinError = nil
            pinLockedUntil = nil
        } catch ProfileSelectError.pinIncorrect(let remaining) {
            pinPromptForIndex = targetIndex
            if let n = remaining, n > 0 {
                pinError = "Incorrect PIN. \(n) \(n == 1 ? "try" : "tries") left."
            } else {
                pinError = "Incorrect PIN."
            }
        } catch ProfileSelectError.pinLocked(_, let retryAt) {
            pinPromptForIndex = targetIndex
            pinLockedUntil = retryAt
            pinError = "Too many attempts. Try again shortly."
        } catch {
            DebugProbe.log("profile select failed: \(error.localizedDescription)")
            pinPromptForIndex = nil
            pinError = nil
            pinLockedUntil = nil
            lastError = "Couldn't switch profile: \(error.localizedDescription)"
        }
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

        // The login token is "unbound" — catalog / playback calls made with
        // it default to the tightest-restricted profile. Bind to the
        // viewer's cached active profile right away so browse and playback
        // reflect their selection. If that profile is PIN-gated, the
        // performProfileSelect call surfaces the PIN sheet on the picker.
        let target = min(max(0, activeProfileIndex), max(0, profiles.count - 1))
        if !profiles.isEmpty {
            await performProfileSelect(targetIndex: target, pin: nil)
        }
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
