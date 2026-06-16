import SwiftUI

struct CategoryDetailView: View {
    let category: Genre
    @StateObject private var vm = CategoryDetailViewModel()

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]

    private var children: [Genre] {
        (category.children ?? []).filter { ($0.name ?? "").isEmpty == false }
    }

    var body: some View {
        Group {
            switch vm.phase {
            case .loading:
                StatePlaceholder(mode: .loading)
            case .failed(let e):
                StatePlaceholder(
                    mode: .error(e.localizedDescription, retry: { Task { await vm.load(category.id) } })
                )
            case .empty:
                if children.isEmpty {
                    StatePlaceholder(mode: .empty("No titles in \(category.name ?? "this category")."))
                } else {
                    childrenOnlyView
                }
            case .loaded(let items):
                loadedView(items: items)
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle(category.name ?? "Category")
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .navigationDestination(for: Genre.self) { CategoryDetailView(category: $0) }
        .task { await vm.load(category.id) }
    }

    private var childrenOnlyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Browse \(category.name ?? "")")
                subcategoryGrid
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func loadedView(items: [Content]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !children.isEmpty {
                    sectionHeader("Subcategories")
                    subcategoryGrid
                }
                if !items.isEmpty {
                    if !children.isEmpty {
                        sectionHeader("All Titles")
                    }
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
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(OTNetTheme.textPrimary)
            .padding(.horizontal, 20)
    }

    private var subcategoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            ForEach(children) { child in
                NavigationLink(value: child) {
                    SubcategoryCard(category: child)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct SubcategoryCard: View {
    let category: Genre

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let count = category.children?.count, count > 0 {
                    Text("\(count) subcategories")
                        .font(.caption)
                        .foregroundStyle(OTNetTheme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OTNetTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(OTNetTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(OTNetTheme.border, lineWidth: 1)
        )
    }
}

@MainActor
final class CategoryDetailViewModel: ObservableObject {
    @Published var phase: Phase<[Content]> = .loading

    func load(_ categoryId: String) async {
        phase = .loading
        do {
            let page = try await OTNetAPI.shared.contentByCategory(categoryId)
            let items = page.items ?? []
            phase = items.isEmpty ? .empty : .loaded(items)
        } catch {
            phase = .failed(error)
        }
    }
}
