import Foundation

enum APIError: Error, LocalizedError {
    case http(Int)
    case paywall(PaywallInfo?)
    case decoding(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .http(let code):     return "HTTP \(code)"
        case .paywall(let info):  return info?.headline ?? "Subscription required"
        case .decoding(let err):  return "Decoding failed: \(err.localizedDescription)"
        case .invalidURL:         return "Invalid URL"
        }
    }
}

extension PaywallInfo {
    /// Best-effort decode from a 402 Payment Required body. The server can
    /// return either `{ paywall: {…} }` (wrapping the block) or the block
    /// fields at the top level, depending on which route 402'd. Tries both.
    static func decodeFrom402(_ data: Data) -> PaywallInfo? {
        struct Wrapped: Decodable { let paywall: PaywallInfo? }
        if let w = try? JSONDecoder().decode(Wrapped.self, from: data), w.paywall != nil {
            return w.paywall
        }
        return try? JSONDecoder().decode(PaywallInfo.self, from: data)
    }
}
