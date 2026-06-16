import Foundation

struct HomepageResponse: Codable {
    let hero: [Content]?
    let rows: [HomepageRow]?
}

struct HomepageRow: Codable, Identifiable {
    var id: String {
        let g = (genre?.id ?? "") + "-" + (genre?.name ?? "")
        return g + "-" + String(items?.count ?? 0)
    }
    let items: [Content]?
    let tileType: String?
    let tileStyle: String?
    let genre: GenreRef?
}
