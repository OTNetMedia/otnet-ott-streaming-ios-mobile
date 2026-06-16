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

    init() {
        precondition(
            !apiKey.isEmpty && apiKey.hasPrefix("otn_") && apiKey != "otn_replace_with_your_publisher_api_key",
            "OTNet API key must be set. Copy OTNetApp/Networking/Secrets.swift.example to Secrets.swift and replace the placeholder."
        )
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let url = try makeURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        DebugProbe.log(url, status: status, bytes: data.count, decoded: String(describing: T.self))
        guard (200..<300).contains(status) else { throw APIError.http(status) }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let url = try makeURL(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        DebugProbe.log(url, status: status, bytes: data.count, decoded: String(describing: T.self))
        guard (200..<300).contains(status) else { throw APIError.http(status) }
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

    func epg(channelId: String? = nil, back: Int? = nil, ahead: Int? = nil) async throws -> EPGResponse {
        var q: [URLQueryItem] = []
        if let channelId { q.append(URLQueryItem(name: "channelId", value: channelId)) }
        if let back      { q.append(URLQueryItem(name: "back",      value: String(back))) }
        if let ahead     { q.append(URLQueryItem(name: "ahead",     value: String(ahead))) }
        return try await get("/catalog/epg", query: q)
    }

    func drmSession(contentId: String, mediaIndex: Int = 0) async throws -> DrmSessionResponse {
        struct Req: Encodable { let contentId: String; let mediaIndex: Int }
        return try await post("/session", body: Req(contentId: contentId, mediaIndex: mediaIndex))
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

struct PlayerErrorReport: Encodable {
    let errorCode: String
    let errorCategory: String
    let message: String
    let severity: String
    let device: String
    let deviceType: String
    let contentId: String?
}
