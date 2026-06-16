import Foundation

struct EPGResponse: Codable {
    let channels: [EPGChannel]?
}

struct ChannelsResponse: Codable {
    let channels: [EPGChannelInfo]?
}

struct EPGChannel: Codable, Identifiable {
    var id: String { channel?.id ?? UUID().uuidString }
    let channel: EPGChannelInfo?
    let playbackUrl: String?
    let programs: [EPGProgram]?
}

struct EPGChannelInfo: Codable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let logo: String?
    let channelNumber: Int?
    let description: String?
    let backgroundImage: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id", name, logo, channelNumber, description, backgroundImage
    }

    var logoURL: URL? { logo.flatMap(URL.init(string:)) }
    var backdropURL: URL? { backgroundImage.flatMap(URL.init(string:)) }
}

struct EPGProgram: Codable, Identifiable {
    var id: String { _id ?? "\(startTime ?? "")-\(displayTitle)" }
    let _id: String?
    let title: String?
    let programName: String?
    let description: String?
    let startTime: String?
    let endTime: String?
    let durationSeconds: Int?
    let contentId: String?
    let content: EPGProgramContent?

    var displayTitle: String {
        content?.title?.nilIfBlank
            ?? programName?.nilIfBlank
            ?? title?.nilIfBlank
            ?? "Live"
    }

    var displayDescription: String? {
        content?.description?.nilIfBlank ?? description?.nilIfBlank
    }

    var thumbnailURL: URL? {
        content?.thumbnail?.nilIfBlank.flatMap(URL.init(string:))
    }

    var startDate: Date? {
        startTime.flatMap(EPGProgram.iso.date(from:))
    }

    var endDate: Date? {
        if let endTime, let d = EPGProgram.iso.date(from: endTime) { return d }
        if let s = startDate, let dur = durationSeconds {
            return s.addingTimeInterval(TimeInterval(dur))
        }
        return nil
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

struct EPGProgramContent: Codable {
    let title: String?
    let thumbnail: String?
    let description: String?
    let genre: String?
}

private extension String {
    var nilIfBlank: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}
