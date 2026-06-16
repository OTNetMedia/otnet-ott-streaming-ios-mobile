import SwiftUI

struct MyListView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var myList: MyListStore
    @State private var showingPicker = false
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]

    var body: some View {
        Group {
            if myList.isLoading && myList.items.isEmpty {
                StatePlaceholder(mode: .loading)
            } else if myList.items.isEmpty {
                StatePlaceholder(mode: .empty("Add titles by tapping +My List on a content page."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(myList.items) { item in
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
                    .padding(.top, 12)
                }
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle("My List")
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if auth.isSignedIn {
                    profileMenu
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            ProfilePickerView()
        }
        .refreshable {
            await myList.refresh(profileIndex: auth.activeProfileIndex)
        }
    }

    private var profileMenu: some View {
        Menu {
            if let viewerName = auth.viewer?.displayName ?? auth.viewer?.email {
                Text("Signed in as \(viewerName)")
            }
            if let active = auth.activeProfile {
                Text("Profile: \(active.displayName)")
            }
            Button { showingPicker = true } label: {
                Label("Switch profile", systemImage: "person.2.circle")
            }
            Button { showingPicker = true } label: {
                Label("Manage profiles", systemImage: "person.crop.circle.badge.plus")
            }
            Divider()
            Button(role: .destructive) {
                Task { await auth.logout() }
            } label: {
                Label("Sign out", systemImage: "arrow.right.square")
            }
        } label: {
            if let profile = auth.activeProfile {
                ProfileAvatar(profile: profile, size: 32, highlighted: false)
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .foregroundStyle(OTNetTheme.textPrimary)
            }
        }
    }

}
