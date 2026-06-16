import AVFoundation
import Foundation

final class FairPlayKeyDelegate: NSObject, AVContentKeySessionDelegate {
    let licenseURL: URL
    let certificateURL: URL
    let onError: ((Error) -> Void)?

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

    private func handle(keyRequest: AVContentKeyRequest) {
        let licenseURL = self.licenseURL
        let certificateURL = self.certificateURL
        let onError = self.onError

        Task {
            do {
                let (certData, _) = try await URLSession.shared.data(from: certificateURL)
                let contentId = (keyRequest.identifier as? String) ?? ""
                let assetIdData = Data(contentId.utf8)
                let spcData = try await keyRequest.makeStreamingContentKeyRequestData(
                    forApp: certData,
                    contentIdentifier: assetIdData,
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
}

func resolveFairPlayUrls(variant: MediaVariant,
                         contentId: String,
                         mediaIndex: Int) async throws -> (license: URL, cert: URL) {
    guard let fairplay = variant.drm?.fairplay,
          let certStr = fairplay.certificateUrl,
          let cert = URL(string: certStr) else {
        throw APIError.invalidURL
    }
    let session = try await OTNetAPI.shared.drmSession(contentId: contentId, mediaIndex: mediaIndex)
    guard let license = URL(string: "https://otnet.io/api/v1/playback/drm/license?token=\(session.token)&system=fairplay") else {
        throw APIError.invalidURL
    }
    return (license, cert)
}
