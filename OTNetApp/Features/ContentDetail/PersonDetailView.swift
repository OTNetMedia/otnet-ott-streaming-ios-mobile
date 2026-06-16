import SwiftUI

struct PersonDetailView: View {
    let personnel: Personnel
    @StateObject private var vm = PersonDetailViewModel()

    private var name: String {
        vm.profile?.name ?? personnel.displayName ?? "Unknown"
    }
    private var headshotURL: URL? {
        vm.profile?.headshotURL ?? personnel.headshotURL
    }
    private var title: String? {
        let profileTitle = vm.profile?.title?.nilIfEmpty
        let personnelRole = personnel.role?.nilIfEmpty
        return profileTitle ?? personnelRole
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headshot.padding(.top, 24)

                VStack(spacing: 8) {
                    Text(name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(OTNetTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let title {
                        Text(title.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(OTNetTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(OTNetTheme.primary.opacity(0.15), in: Capsule())
                    }
                }
                .padding(.horizontal, 24)

                if !infoRows.isEmpty {
                    infoCard
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }

                creditsSection
                    .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OTNetTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            if let id = personnel.person?.id {
                await vm.load(personId: id)
            }
        }
    }

    private var headshot: some View {
        AsyncImage(url: headshotURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180, alignment: .top)
                    .clipped()
            default:
                ZStack {
                    OTNetTheme.card
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(OTNetTheme.textSecondary)
                }
                .frame(width: 180, height: 180)
            }
        }
        .frame(width: 180, height: 180)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }

    private struct InfoRow {
        let label: String
        let value: String
    }

    private var infoRows: [InfoRow] {
        var rows: [InfoRow] = []
        if let role = personnel.role, !role.isEmpty,
           role.lowercased() != (vm.profile?.title ?? "").lowercased() {
            rows.append(.init(label: "Role", value: role))
        }
        if let team = vm.profile?.team?.name, !team.isEmpty {
            rows.append(.init(label: "Team", value: team))
        }
        if let org = vm.profile?.organization?.name, !org.isEmpty {
            rows.append(.init(label: "Network", value: org))
        }
        return rows
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(infoRows.enumerated()), id: \.offset) { idx, row in
                HStack {
                    Text(row.label)
                        .font(.subheadline)
                        .foregroundStyle(OTNetTheme.textSecondary)
                    Spacer()
                    Text(row.value)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OTNetTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                if idx < infoRows.count - 1 {
                    Divider()
                        .background(OTNetTheme.textSecondary.opacity(0.15))
                        .padding(.leading, 16)
                }
            }
        }
        .background(OTNetTheme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Also appears in")
                    .font(.title3.bold())
                    .foregroundStyle(OTNetTheme.textPrimary)
                if vm.credits.count > 0 {
                    Text("\(vm.credits.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OTNetTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(OTNetTheme.muted, in: Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            if vm.isLoadingCredits && vm.credits.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
            } else if vm.credits.isEmpty {
                Text("No other credits available.")
                    .font(.subheadline)
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(vm.credits) { item in
                            NavigationLink(value: item) {
                                PosterCard(
                                    url: item.posterURL,
                                    title: item.displayTitle,
                                    ageRating: item.ageRating
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
final class PersonDetailViewModel: ObservableObject {
    @Published var profile: PersonProfile?
    @Published var credits: [Content] = []
    @Published var isLoadingCredits = false

    func load(personId: String) async {
        async let profileTask: Void = loadProfile(personId)
        async let creditsTask: Void = loadCredits(personId)
        _ = await (profileTask, creditsTask)
    }

    private func loadProfile(_ id: String) async {
        do {
            profile = try await OTNetAPI.shared.person(id: id)
        } catch {
            DebugProbe.log("person load failed: \(error)")
        }
    }

    private func loadCredits(_ id: String) async {
        isLoadingCredits = true
        defer { isLoadingCredits = false }
        do {
            let page = try await OTNetAPI.shared.contentForPerson(id, limit: 40)
            credits = page.items ?? []
        } catch {
            DebugProbe.log("person credits load failed: \(error)")
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
