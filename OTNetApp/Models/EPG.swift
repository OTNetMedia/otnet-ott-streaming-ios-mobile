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

    // Pre-parsed at decode time so the EPG grid doesn't hit
    // `ISO8601DateFormatter.date(from:)` per tile per render. With dozens of
    // tiles × many channels × frequent re-renders, that was meaningful CPU.
    let startDate: Date?
    let endDate: Date?
    let thumbnailURL: URL?

    var displayTitle: String {
        content?.title?.nilIfBlank
            ?? programName?.nilIfBlank
            ?? title?.nilIfBlank
            ?? "Live"
    }

    var displayDescription: String? {
        content?.description?.nilIfBlank ?? description?.nilIfBlank
    }

    enum CodingKeys: String, CodingKey {
        case _id, title, programName, description
        case startTime, endTime, durationSeconds, contentId, content
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self._id = try c.decodeIfPresent(String.self, forKey: ._id)
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.programName = try c.decodeIfPresent(String.self, forKey: .programName)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
        self.endTime = try c.decodeIfPresent(String.self, forKey: .endTime)
        self.durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        self.contentId = try c.decodeIfPresent(String.self, forKey: .contentId)
        let content = try c.decodeIfPresent(EPGProgramContent.self, forKey: .content)
        self.content = content

        let parsedStart = self.startTime.flatMap(EPGProgram.iso.date(from:))
        self.startDate = parsedStart
        if let endTime = self.endTime, let d = EPGProgram.iso.date(from: endTime) {
            self.endDate = d
        } else if let s = parsedStart, let dur = self.durationSeconds {
            self.endDate = s.addingTimeInterval(TimeInterval(dur))
        } else {
            self.endDate = nil
        }
        self.thumbnailURL = content?.thumbnail?.nilIfBlank.flatMap(URL.init(string:))
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
