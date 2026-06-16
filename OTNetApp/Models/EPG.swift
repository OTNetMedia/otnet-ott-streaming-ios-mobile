import Foundation

struct EPGResponse: Codable {
    let channels: [EPGChannel]?
}

struct EPGChannel: Codable, Identifiable {
    var id: String { channel?.id ?? UUID().uuidString }
    let channel: EPGChannelInfo?
    let playbackUrl: String?
    let programs: [EPGProgram]?
}

struct EPGChannelInfo: Codable, Identifiable {
    let id: String?
    let name: String?
    let logo: String?
    enum CodingKeys: String, CodingKey { case id = "_id", name, logo }
}

struct EPGProgram: Codable, Identifiable {
    var id: String { _id ?? UUID().uuidString }
    let _id: String?
    let title: String?
    let description: String?
    let startTime: String?
    let endTime: String?
}
