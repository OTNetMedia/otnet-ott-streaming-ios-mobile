import SwiftUI

struct ContentDetailView: View {
    let content: Content
    @State private var showingPlayer = false
    @StateObject private var vm = ContentDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroSection
                titleSection
                metadataSection
                playButton

                if let synopsis = (vm.detail ?? content).description, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.body)
                        .foregroundStyle(OTNetTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                }

                if (vm.detail ?? content).isSeries {
                    SeasonsView(seriesId: content.id)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 60)
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showingPlayer) {
            PlayerView(content: vm.detail ?? content)
                .ignoresSafeArea()
        }
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .task { await vm.load(content.id) }
    }

    private var heroSection: some View {
        let displayed = vm.detail ?? content
        return AsyncImage(url: displayed.landscapeURL ?? displayed.posterURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            default:
                Rectangle().fill(OTNetTheme.card)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipped()
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, OTNetTheme.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 120)
        }
    }

    private var titleSection: some View {
        let displayed = vm.detail ?? content
        return Group {
            if let url = displayed.titleImageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFit()
                    } else {
                        Text(displayed.displayTitle)
                            .font(.largeTitle).bold()
                            .foregroundStyle(OTNetTheme.textPrimary)
                    }
                }
                .frame(maxHeight: 120)
            } else {
                Text(displayed.displayTitle)
                    .font(.largeTitle).bold()
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var metadataSection: some View {
        let displayed = vm.detail ?? content
        return HStack(spacing: 8) {
            if let r = displayed.ageRating { AgeRatingBadge(rating: r) }
            if let t = displayed.contentType ?? displayed.type {
                MetaPill(text: t.capitalized)
            }
            if let g = displayed.primaryGenreName { MetaPill(text: g) }
        }
        .padding(.horizontal, 20)
    }

    private var playButton: some View {
        Button {
            showingPlayer = true
        } label: {
            Label("Play", systemImage: "play.fill")
                .bold()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(OTNetTheme.primary)
        .padding(.horizontal, 20)
    }
}

@MainActor
final class ContentDetailViewModel: ObservableObject {
    @Published var detail: Content?

    func load(_ id: String) async {
        do {
            detail = try await OTNetAPI.shared.content(id: id)
        } catch {
            DebugProbe.log("content detail load failed: \(error)")
        }
    }
}
