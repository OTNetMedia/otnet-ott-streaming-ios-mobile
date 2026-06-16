import SwiftUI

struct AgeRatingBadge: View {
    let rating: String

    var body: some View {
        Text(rating.uppercased())
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
    }

    private var color: Color {
        switch rating.uppercased() {
        case "U", "G":           return Color(red: 0.18, green: 0.65, blue: 0.30)
        case "PG":               return Color(red: 0.95, green: 0.78, blue: 0.18)
        case "12A", "12", "PG-13": return Color(red: 0.95, green: 0.55, blue: 0.18)
        case "15":               return Color(red: 0.95, green: 0.35, blue: 0.55)
        case "18", "R":          return Color(red: 0.85, green: 0.20, blue: 0.20)
        case "R18", "NC-17":     return Color(red: 0.50, green: 0.10, blue: 0.10)
        default:                 return Color.gray
        }
    }
}
