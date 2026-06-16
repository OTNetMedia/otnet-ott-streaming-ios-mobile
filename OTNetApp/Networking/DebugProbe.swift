import Foundation

enum DebugProbe {
    static func log(_ url: URL, status: Int, bytes: Int, decoded: String) {
        #if DEBUG
        print("[OTNetAPI] \(status) \(decoded) \(bytes)b. \(url.absoluteString)")
        #endif
    }

    static func log(_ message: String) {
        #if DEBUG
        print("[OTNetAPI] \(message)")
        #endif
    }
}
