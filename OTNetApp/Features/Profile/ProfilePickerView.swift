import SwiftUI

struct ProfilePickerView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var managing = false
    @State private var editingProfile: ProfileEditTarget?

    enum ProfileEditTarget: Identifiable {
        case new
        case existing(Int, ViewerProfile)
        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let i, _): return "existing-\(i)"
            }
        }
    }

    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 18), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(managing ? "Manage Profiles" : "Who's watching?")
                        .font(.largeTitle.bold())
                        .foregroundStyle(OTNetTheme.textPrimary)
                        .padding(.top, 24)

                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(Array(auth.profiles.enumerated()), id: \.element.id) { idx, profile in
                            tile(for: profile, index: idx)
                        }
                        if auth.profiles.count < auth.profileLimit {
                            addTile
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 12)
                }
            }
            .background(OTNetTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(OTNetTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(managing ? "Done" : "Manage") {
                        withAnimation { managing.toggle() }
                    }
                    .foregroundStyle(OTNetTheme.primary)
                }
            }
            .toolbarBackground(OTNetTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingProfile) { target in
                switch target {
                case .new:
                    ProfileEditView(mode: .create)
                case .existing(let idx, let profile):
                    ProfileEditView(mode: .edit(index: idx, profile: profile))
                }
            }
        }
        .task { await auth.refreshProfiles() }
    }

    private func tile(for profile: ViewerProfile, index: Int) -> some View {
        Button {
            if managing {
                editingProfile = .existing(index, profile)
            } else {
                auth.setActiveProfile(index: index)
                dismiss()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ProfileAvatar(profile: profile, size: 92,
                                  highlighted: index == auth.activeProfileIndex && !managing)
                    if managing {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(OTNetTheme.primary, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                Text(profile.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .lineLimit(1)
                if profile.kids == true {
                    Text("KIDS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(OTNetTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var addTile: some View {
        Button { editingProfile = .new } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(OTNetTheme.border, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .frame(width: 92, height: 92)
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(OTNetTheme.textSecondary)
                }
                Text("Add profile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OTNetTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProfileAvatar: View {
    let profile: ViewerProfile
    var size: CGFloat = 40
    var highlighted: Bool = false

    var body: some View {
        ZStack {
            if let url = profile.avatarURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(
                highlighted ? OTNetTheme.primary : Color.white.opacity(0.08),
                lineWidth: highlighted ? 3 : 1
            )
        )
    }

    private var fallback: some View {
        ZStack {
            OTNetTheme.primary.opacity(0.18)
            Text(profile.initial)
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(OTNetTheme.primary)
        }
    }
}
