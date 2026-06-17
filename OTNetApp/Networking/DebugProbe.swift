import Foundation
import OSLog

enum DebugProbe {
    private static let logger = Logger(subsystem: "io.otnet.app", category: "OTNetAPI")

    static func log(_ url: URL, status: Int, bytes: Int, decoded: String) {
        let msg = "\(status) \(decoded) \(bytes)b. \(url.absoluteString)"
        #if DEBUG
        print("[OTNetAPI] \(msg)")
        #endif
        logger.log("\(msg, privacy: .public)")
    }

    static func log(_ message: String) {
        #if DEBUG
        print("[OTNetAPI] \(message)")
        #endif
        logger.log("\(message, privacy: .public)")
    }
}
