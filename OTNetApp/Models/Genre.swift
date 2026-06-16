import Foundation

struct Genre: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let slug: String?
    let order: Int?
    let parent: String?
    let children: [Genre]?

    enum CodingKeys: String, CodingKey {
        case id = "_id", name, slug, order, parent, children
    }

    static func == (lhs: Genre, rhs: Genre) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct GenreRef: Codable, Hashable {
    let id: String?
    let name: String?
    enum CodingKeys: String, CodingKey { case id = "_id", name }
}
