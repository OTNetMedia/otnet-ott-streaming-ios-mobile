import Foundation

enum APIError: Error, LocalizedError {
    case http(Int)
    case decoding(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .http(let code):    return "HTTP \(code)"
        case .decoding(let err): return "Decoding failed: \(err.localizedDescription)"
        case .invalidURL:        return "Invalid URL"
        }
    }
}
