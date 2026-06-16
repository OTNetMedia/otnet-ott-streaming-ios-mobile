import SwiftUI

struct CastAndCrewView: View {
    let content: Content

    private var personnel: [Personnel] {
        (content.personnel ?? []).filter { $0.displayName != nil }
    }

    private var groups: [(role: String, members: [Personnel])] {
        let grouped = Dictionary(grouping: personnel) { ($0.role ?? "Crew").capitalized }
        let order = ["Actor", "Director", "Writer", "Producer", "Executive Producer", "Composer", "Editor"]
        return grouped
            .map { (role: $0.key, members: $0.value) }
            .sorted { lhs, rhs in
                let li = order.firstIndex(of: lhs.role) ?? Int.max
                let ri = order.firstIndex(of: rhs.role) ?? Int.max
                if li != ri { return li < ri }
                return lhs.role < rhs.role
            }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(width: geo.size.width)

                    if personnel.isEmpty {
                        Text("No cast or crew information available.")
                            .font(.subheadline)
                            .foregroundStyle(OTNetTheme.textSecondary)
                            .padding(.horizontal, 20)
                    } else {
                        ForEach(groups, id: \.role) { group in
                            section(title: displayName(for: group.role, count: group.members.count),
                                    members: group.members)
                        }
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
                .padding(.bottom, 60)
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle("Cast & Crew")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OTNetTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func displayName(for role: String, count: Int) -> String {
        let plural: String
        switch role.lowercased() {
        case "actor": plural = "Cast"
        case "director": plural = count > 1 ? "Directors" : "Director"
        case "writer": plural = count > 1 ? "Writers" : "Writer"
        case "producer": plural = count > 1 ? "Producers" : "Producer"
        default: plural = role
        }
        return plural
    }

    private func header(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: content.landscapeURL ?? content.posterURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: 180, alignment: .top)
                        .clipped()
                        .blur(radius: 12)
                        .overlay(Color.black.opacity(0.35))
                default:
                    Rectangle().fill(OTNetTheme.card)
                        .frame(width: width, height: 180)
                }
            }
            .frame(width: width, height: 180)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, OTNetTheme.background],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(content.displayTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4)
                Text("\(personnel.count) \(personnel.count == 1 ? "credit" : "credits")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: width)
    }

    private func section(title: String, members: [Personnel]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(OTNetTheme.textPrimary)
                Text("\(members.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(OTNetTheme.muted, in: Capsule())
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(members, id: \.id) { person in
                    PersonCard(person: person)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct PersonCard: View {
    let person: Personnel

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: person.headshotURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 96, height: 96, alignment: .top)
                        .clipped()
                default:
                    ZStack {
                        Circle().fill(OTNetTheme.card)
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundStyle(OTNetTheme.textSecondary)
                    }
                    .frame(width: 96, height: 96)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )

            VStack(spacing: 2) {
                Text(person.displayName ?? "Unknown")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let role = person.role, !role.isEmpty {
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(OTNetTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
