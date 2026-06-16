import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .onAppear { fieldFocused = true }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(OTNetTheme.card, in: Circle())
                    .overlay(Circle().strokeBorder(OTNetTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            searchField
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(OTNetTheme.textSecondary)

            TextField("Search titles, genres, people…", text: $vm.query)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .foregroundStyle(OTNetTheme.textPrimary)
                .onChange(of: vm.query) { newValue in
                    vm.scheduleSearch(for: newValue)
                }

            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    fieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(OTNetTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(OTNetTheme.card, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(fieldFocused ? OTNetTheme.primary.opacity(0.7) : OTNetTheme.border,
                              lineWidth: fieldFocused ? 1.5 : 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle:
            promptView
        case .loading:
            VStack { ProgressView().tint(OTNetTheme.textSecondary) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty(let q):
            placeholderView(
                icon: "magnifyingglass",
                title: "No results",
                message: "Nothing matches \"\(q)\". Try a different word."
            )
        case .failed(let err):
            placeholderView(
                icon: "exclamationmark.triangle",
                title: "Couldn't search",
                message: err
            )
        case .results(let items, let total):
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(total) \(total == 1 ? "result" : "results")")
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(OTNetTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var promptView: some View {
        placeholderView(
            icon: "magnifyingglass",
            title: "Search",
            message: "Find titles, genres, or people."
        )
    }

    private func placeholderView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(OTNetTheme.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(OTNetTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(OTNetTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case empty(String)
        case results([Content], total: Int)
        case failed(String)
    }

    @Published var query: String = ""
    @Published private(set) var state: State = .idle
    private var debounceTask: Task<Void, Never>?

    func scheduleSearch(for query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            state = .idle
            return
        }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSearch(query: trimmed)
        }
    }

    private func runSearch(query: String) async {
        state = .loading
        do {
            let page = try await OTNetAPI.shared.searchContent(query)
            let items = page.items ?? []
            if items.isEmpty {
                state = .empty(query)
            } else {
                state = .results(items, total: items.count)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
