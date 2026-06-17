import Foundation

actor OTNetAPI {
    static let shared = OTNetAPI()

    private let baseURL = URL(string: "https://otnet.io/api/v1")!
    private let apiKey  = Secrets.otNetApiKey
    private let session = URLSession(configuration: .default)
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    private let encoder = JSONEncoder()
    private var viewerToken: String?

    init() {
        precondition(
            !apiKey.isEmpty && apiKey.hasPrefix("otn_") && apiKey != "otn_replace_with_your_publisher_api_key",
            "OTNet API key must be set. Copy OTNetApp/Networking/Secrets.swift.example to Secrets.swift and replace the placeholder."
        )
    }

    func setViewerToken(_ token: String?) {
        self.viewerToken = token
    }

    func currentViewerToken() -> String? { viewerToken }

    /// When the viewer is signed in, attach the Bearer everywhere except the
    /// FairPlay license endpoint (auth'd by the DRM session token in the
    /// query string; sending a Bearer there can cause a 403).
    private func viewerTokenAllowed(for path: String) -> Bool {
        let normalized = path.hasPrefix("/") ? path : "/" + path
        if normalized.contains("/playback/drm/license") { return false }
        return true
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let url = try makeURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        if let viewerToken, viewerTokenAllowed(for: path) {
            request.setValue("Bearer \(viewerToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        DebugProbe.log(url, status: status, bytes: data.count, decoded: String(describing: T.self))
        guard (200..<300).contains(status) else { throw APIError.http(status) }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    /// Like `get<T>`, but returns the raw bytes (no decoding). Use for
    /// diagnosing shape mismatches when typed decoding loses fields silently.
    func rawGet(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        let url = try makeURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        if let viewerToken, viewerTokenAllowed(for: path) {
            request.setValue("Bearer \(viewerToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        DebugProbe.log(url, status: status, bytes: data.count, decoded: "raw")
        guard (200..<300).contains(status) else { throw APIError.http(status) }
        return data
    }

    func post<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        let url = try makeURL(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let viewerToken, viewerTokenAllowed(for: path) {
            req.setValue("Bearer \(viewerToken)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        DebugProbe.log(url, status: status, bytes: data.count, decoded: String(describing: T.self))
        guard (200..<300).contains(status) else {
            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                DebugProbe.log("POST \(path) error body: \(body.prefix(400))")
            }
            throw APIError.http(status)
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    private func makeURL(path: String, query: [URLQueryItem] = []) throws -> URL {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(trimmed),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }
}

extension OTNetAPI {
    func homepage() async throws -> HomepageResponse {
        try await get("/catalog/homepage")
    }

    func categoriesTree() async throws -> [Genre] {
        try await get("/catalog/categories/tree")
    }

    func categoriesFlat() async throws -> [Genre] {
        try await get("/catalog/categories")
    }

    func content(id: String) async throws -> Content {
        try await get("/catalog/content/\(id)")
    }

    func children(id: String) async throws -> ChildrenResponse {
        try await get("/catalog/content/\(id)/children")
    }

    func contentByCategory(_ categoryId: String, page: Int = 1, limit: Int = 30) async throws -> CategoryPage {
        let q = [
            URLQueryItem(name: "page",  value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        return try await get("/catalog/content/category/\(categoryId)", query: q)
    }

    func searchContent(_ query: String, limit: Int = 40) async throws -> CategoryPage {
        let q = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit",  value: String(limit)),
        ]
        return try await get("/catalog/content", query: q)
    }

    func person(id: String) async throws -> PersonProfile {
        try await get("/catalog/people/\(id)")
    }

    func contentForPerson(_ personId: String, page: Int = 1, limit: Int = 30) async throws -> CategoryPage {
        let q = [
            URLQueryItem(name: "personId", value: personId),
            URLQueryItem(name: "page",     value: String(page)),
            URLQueryItem(name: "limit",    value: String(limit)),
        ]
        return try await get("/catalog/content", query: q)
    }

    func epg(channelId: String? = nil, back: Int? = nil, ahead: Int? = nil) async throws -> EPGResponse {
        var q: [URLQueryItem] = []
        if let channelId { q.append(URLQueryItem(name: "channelId", value: channelId)) }
        if let back      { q.append(URLQueryItem(name: "back",      value: String(back))) }
        if let ahead     { q.append(URLQueryItem(name: "ahead",     value: String(ahead))) }
        return try await get("/catalog/epg", query: q)
    }

    func channels() async throws -> ChannelsResponse {
        try await get("/catalog/channels")
    }

    func settings() async throws -> PublisherSettings {
        try await get("/catalog/settings")
    }

    // MARK: - Viewer auth

    func register(email: String, password: String, displayName: String) async throws -> AuthResponse {
        struct Req: Encodable { let email: String; let password: String; let displayName: String }
        return try await post("/viewer/auth/register",
                              body: Req(email: email, password: password, displayName: displayName))
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        struct Req: Encodable { let email: String; let password: String }
        return try await post("/viewer/auth/login", body: Req(email: email, password: password))
    }

    func refreshAuth(refreshToken: String) async throws -> RefreshResponse {
        struct Req: Encodable { let refreshToken: String }
        return try await post("/viewer/auth/refresh", body: Req(refreshToken: refreshToken))
    }

    func logout() async {
        struct Req: Encodable {}
        struct Empty: Decodable {}
        do { let _: Empty = try await post("/viewer/auth/logout", body: Req()) }
        catch { DebugProbe.log("logout failed: \(error)") }
    }

    // MARK: - Viewer profiles

    func profiles() async throws -> ProfilesResponse {
        try await get("/viewer/profiles")
    }

    func createProfile(name: String, avatar: String?, kids: Bool) async throws -> ProfilesResponse {
        struct Req: Encodable { let name: String; let avatar: String?; let kids: Bool }
        return try await post("/viewer/profiles",
                              body: Req(name: name, avatar: avatar, kids: kids))
    }

    func updateProfile(index: Int, name: String?, avatar: String?, kids: Bool?) async throws -> ProfilesResponse {
        struct Req: Encodable { let index: Int; let name: String?; let avatar: String?; let kids: Bool? }
        return try await send("PATCH", "/viewer/profiles",
                              body: Req(index: index, name: name, avatar: avatar, kids: kids))
    }

    func deleteProfile(index: Int) async throws -> ProfilesResponse {
        struct Req: Encodable { let index: Int }
        return try await send("DELETE", "/viewer/profiles", body: Req(index: index))
    }

    // MARK: - Viewer list (My List)

    func myList(profileIndex: Int) async throws -> ViewerListResponse {
        try await get("/viewer/list",
                      query: [URLQueryItem(name: "profileIndex", value: String(profileIndex))])
    }

    func addToList(contentId: String, profileIndex: Int) async throws {
        struct Req: Encodable { let contentId: String; let profileIndex: Int }
        struct Ack: Decodable { let success: Bool? }
        let _: Ack = try await post("/viewer/list",
                                    body: Req(contentId: contentId, profileIndex: profileIndex))
    }

    // MARK: - Continue watching (telemetry/progress)

    func watchProgress(profileIndex: Int) async throws -> WatchProgressResponse {
        try await get("/telemetry/progress",
                      query: [URLQueryItem(name: "profileIndex", value: String(profileIndex))])
    }

    /// Authenticated watch-progress write. The Bearer must be the
    /// `analyticsToken` from the matching `/playback/.../mint` response —
    /// it's a drm_session JWT scoped to viewerId + contentId, and the
    /// server's POST handler buckets writes into `WatchProgress` only when it
    /// sees that token. Sending the viewer access JWT here routes the write
    /// into a separate anonymous collection that the viewer GET never reads.
    func postWatchProgress(
        analyticsToken: String,
        profileIndex: Int,
        progressSeconds: Int,
        durationSeconds: Int
    ) async throws {
        struct Req: Encodable {
            let profileIndex: Int
            let progressSeconds: Int
            let durationSeconds: Int
        }
        struct Ack: Decodable { let success: Bool? }
        let _: Ack = try await post(
            "/telemetry/progress",
            body: Req(
                profileIndex: profileIndex,
                progressSeconds: progressSeconds,
                durationSeconds: durationSeconds
            ),
            extraHeaders: ["Authorization": "Bearer \(analyticsToken)"]
        )
    }

    func removeFromList(contentId: String, profileIndex: Int) async throws {
        struct Req: Encodable { let contentId: String; let profileIndex: Int }
        struct Ack: Decodable { let success: Bool? }
        let _: Ack = try await send("DELETE", "/viewer/list",
                                    body: Req(contentId: contentId, profileIndex: profileIndex))
    }

    /// Same plumbing as `post`, parameterised by HTTP method (used for PATCH/DELETE
    /// since both carry a JSON body on the profiles endpoint).
    func send<Body: Encodable, T: Decodable>(_ method: String, _ path: String, body: Body) async throws -> T {
        let url = try makeURL(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let viewerToken, viewerTokenAllowed(for: path) {
            req.setValue("Bearer \(viewerToken)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        DebugProbe.log(url, status: status, bytes: data.count, decoded: String(describing: T.self))
        guard (200..<300).contains(status) else { throw APIError.http(status) }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    /// Mint a playback session. Returns the HLS master URL conditioned for
    /// this device, plus a drm_session JWT (exposed as both `sessionToken`
    /// and `analyticsToken`) used for both the license endpoint and
    /// telemetry writes. Use this instead of `variant.entrypoint` from the
    /// catalog — that's the raw upstream (often DASH `.mpd`) and AVPlayer
    /// cannot consume it.
    ///
    /// `viewerToken` (the viewer access JWT) MUST be passed in the body when
    /// a viewer is signed in, so the server embeds `viewerId` into the
    /// returned drm_session JWT. Without it, telemetry writes route into
    /// AnonymousProgress instead of the per-viewer WatchProgress collection.
    func mintPlayback(contentId: String, protocolName: String = "hls") async throws -> MintResponse {
        struct Req: Encodable {
            let contentId: String
            let `protocol`: String
            let viewerToken: String?
        }
        return try await post(
            "/playback/vod/mint",
            body: Req(contentId: contentId, protocol: protocolName, viewerToken: viewerToken)
        )
    }

    func mintLive(channelId: String, protocolName: String = "hls") async throws -> MintResponse {
        struct Req: Encodable {
            let `protocol`: String
            let viewerToken: String?
        }
        return try await post(
            "/playback/live/\(channelId)/mint",
            body: Req(protocol: protocolName, viewerToken: viewerToken)
        )
    }

    func reportPlayerError(_ report: PlayerErrorReport) async {
        do {
            struct Ack: Decodable { let ok: Bool? }
            let _: Ack = try await post("/telemetry/player-error", body: report)
        } catch {
            DebugProbe.log("player-error report failed: \(error)")
        }
    }
}

struct ChildrenResponse: Decodable {
    let items: [Content]?
}

struct CategoryPage: Decodable {
    let items: [Content]?
    let total: Int?
    let page: Int?
    let totalPages: Int?
}

struct MintResponse: Decodable {
    let playback: Playback

    struct Playback: Decodable {
        let masterUrl: String
        let sessionToken: String?
        /// drm_session JWT scoped to this playback session — carries viewerId +
        /// contentId. Must be sent as the `Authorization: Bearer` on
        /// `/telemetry/progress` writes; the viewer access JWT routes writes
        /// into a different (anonymous) collection.
        let analyticsToken: String?
        let drm: MintDrm?
        let resources: PlaybackResources?
        let adbreaks: AdBreaks?

        var effectiveToken: String? { sessionToken ?? drm?.token }
        var watchProgressToken: String? { analyticsToken ?? sessionToken }
    }

    struct MintDrm: Decodable {
        let sessionDrm: Bool?
        let provider: String?
        let fairplay: MintFairplay?
        let token: String?
    }

    struct MintFairplay: Decodable {
        let certificateUrl: String
    }
}

struct PlaybackResources: Decodable {
    let poster: String?
    let bif: String?
    let waveform: String?
    let metadata: String?

    var bifURL: URL? { bif.flatMap(URL.init(string:)) }
}

struct AdBreaks: Decodable {
    let totalDuration: Double?
    let blockSkipping: Bool?
    let breaks: [AdBreak]?
}

struct AdBreak: Decodable, Hashable, Identifiable {
    var id: String { (trackingId ?? "") + "-" + String(startTime ?? 0) }
    let startTime: Double?
    let duration: Double?
    let type: String?
    let name: String?
    let advertiser: String?
    let adTitle: String?
    let adDescription: String?
    let clickUrl: String?
    let ctaText: String?
    let skippable: Bool?
    let trackingId: String?

    var endTime: Double? {
        guard let s = startTime, let d = duration else { return nil }
        return s + d
    }
}

struct PlayerErrorReport: Encodable {
    let errorCode: String
    let errorCategory: String
    let message: String
    let severity: String
    let device: String
    let deviceType: String
    let contentId: String?
}
