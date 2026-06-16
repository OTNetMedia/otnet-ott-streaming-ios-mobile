import AVFoundation
import Foundation

final class FairPlayKeyDelegate: NSObject, AVContentKeySessionDelegate {
    let licenseURL: URL
    let certificateURL: URL
    let onError: ((Error) -> Void)?

    private var cachedCertificate: Data?

    init(licenseURL: URL, certificateURL: URL, onError: ((Error) -> Void)? = nil) {
        self.licenseURL = licenseURL
        self.certificateURL = certificateURL
        self.onError = onError
    }

    func contentKeySession(_ session: AVContentKeySession,
                           didProvide keyRequest: AVContentKeyRequest) {
        handle(keyRequest: keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession,
                           didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        handle(keyRequest: keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession,
                           contentKeyRequest keyRequest: AVContentKeyRequest,
                           didFailWithError err: Error) {
        DebugProbe.log("FairPlay key request failed: \(err.localizedDescription)")
        onError?(err)
    }

    private func handle(keyRequest: AVContentKeyRequest) {
        // The HLS manifest emits identifiers like `skd://<kid>`. FairPlay
        // expects just the part after `skd://` as the content identifier.
        guard
            let identifier = keyRequest.identifier as? String,
            let kidRange = identifier.range(of: "skd://"),
            let contentIdData = String(identifier[kidRange.upperBound...]).data(using: .utf8)
        else {
            let err = APIError.invalidURL
            keyRequest.processContentKeyResponseError(err)
            onError?(err)
            return
        }

        Task {
            do {
                let certData = try await fetchCertificate()
                let spcData = try await keyRequest.makeStreamingContentKeyRequestData(
                    forApp: certData,
                    contentIdentifier: contentIdData,
                    options: nil
                )

                var req = URLRequest(url: licenseURL)
                req.httpMethod = "POST"
                req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                req.httpBody = spcData

                let (ckcData, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                DebugProbe.log("FairPlay license HTTP \(status) bytes=\(ckcData.count)")
                guard (200..<300).contains(status) else {
                    throw APIError.http(status)
                }

                let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                keyRequest.processContentKeyResponse(keyResponse)
            } catch {
                keyRequest.processContentKeyResponseError(error)
                onError?(error)
            }
        }
    }

    private func fetchCertificate() async throws -> Data {
        if let cached = cachedCertificate { return cached }
        let (data, response) = try await URLSession.shared.data(from: certificateURL)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else { throw APIError.http(status) }
        cachedCertificate = data
        return data
    }
}
