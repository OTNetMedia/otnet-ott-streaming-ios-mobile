import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var continueWatching: ContinueWatchingStore
    @EnvironmentObject private var auth: AuthStore

    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var didTriggerThisDrag = false
    @State private var didHaptic = false
    @State private var resumeTarget: ResumeTarget?
    private let pullThreshold: CGFloat = 80

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: OTNetTheme.rowGap) {
                switch vm.phase {
                case .loading:
                    StatePlaceholder(mode: .loading).frame(height: 400)
                case .empty:
                    StatePlaceholder(mode: .empty("No content yet. Add some in the dashboard."))
                        .frame(height: 400)
                case .failed(let err):
                    StatePlaceholder(
                        mode: .error(err.localizedDescription, retry: { Task { await vm.load() } })
                    ).frame(height: 400)
                case .loaded(let homepage):
                    if let hero = homepage.hero, !hero.isEmpty {
                        HeroBanner(items: hero)
                    }
                    if !continueWatching.items.isEmpty {
                        ContinueWatchingRow(
                            items: continueWatching.items,
                            resolve: { continueWatching.content(for: $0) },
                            onResume: { content, startAt in
                                resumeTarget = ResumeTarget(content: content, startAt: startAt)
                            }
                        )
                    }
                    ForEach(homepage.rows ?? []) { row in
                        ContentRow(row: row)
                    }
                }
            }
            .padding(.bottom, 40)
            .offset(y: isRefreshing ? 60 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isRefreshing)
        }
        .ignoresSafeArea(edges: .top)
        .background(OTNetTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .background(
            // Reaches into the underlying UIScrollView so we can read its real
            // bounce offset. SwiftUI ScrollView's bounce isn't exposed via
            // GeometryReader reliably in iOS 16.
            ScrollOffsetReader { y in
                handle(rawY: y)
            }
            .frame(width: 0, height: 0)
        )
        .overlay(alignment: .top) {
            PullToRefreshIndicator(
                progress: min(1, max(0, pullOffset / pullThreshold)),
                isRefreshing: isRefreshing
            )
            .padding(.top, 64)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            NavigationLink(value: SearchRoute()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.55), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .navigationDestination(for: Genre.self) { CategoryDetailView(category: $0) }
        .navigationDestination(for: SearchRoute.self) { _ in SearchView() }
        .fullScreenCover(item: $resumeTarget) { target in
            PlayerView(content: target.content, startAt: target.startAt)
                .ignoresSafeArea()
        }
        .task { await refreshAll() }
    }

    private func handle(rawY: CGFloat) {
        // UIScrollView reports contentOffset.y. At top, this equals
        // -adjustedContentInset.top. Pulling down makes y more negative.
        // Convert to a positive "pull distance" relative to the natural top.
        // We track the *additional* negative offset below the resting top.
        let pull = max(0, -rawY)
        pullOffset = pull
        DebugProbe.log("home pull rawY=\(Int(rawY)) pull=\(Int(pull)) refreshing=\(isRefreshing)")

        if pull >= pullThreshold, !isRefreshing, !didTriggerThisDrag {
            didTriggerThisDrag = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { await runRefresh() }
        }

        if pull >= pullThreshold * 0.85, !didHaptic, !isRefreshing {
            didHaptic = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        if pull <= 1 {
            didTriggerThisDrag = false
            didHaptic = false
        }
    }

    private func runRefresh() async {
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isRefreshing = true
            }
        }
        let start = Date()
        await refreshAll()
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < 0.7 {
            try? await Task.sleep(nanoseconds: UInt64((0.7 - elapsed) * 1_000_000_000))
        }
        await MainActor.run {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isRefreshing = false
            }
        }
    }

    private func refreshAll() async {
        async let home: Void = vm.load()
        async let cw: Void = {
            if auth.isSignedIn {
                await continueWatching.refresh(profileIndex: auth.activeProfileIndex)
            }
        }()
        _ = await (home, cw)
    }
}

// MARK: - Continue Watching resume target

struct ResumeTarget: Identifiable, Hashable {
    let content: Content
    let startAt: Double
    var id: String { content.id }
}

// MARK: - UIScrollView offset reader

/// Walks up the view hierarchy to find the nearest UIScrollView and observes
/// its contentOffset.y via KVO. This is the only mechanism that reliably
/// tracks SwiftUI ScrollView bounce on iOS 16.
private struct ScrollOffsetReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let v = ProbeView()
        v.onChange = onChange
        return v
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.onChange = onChange
    }

    final class ProbeView: UIView {
        var onChange: ((CGFloat) -> Void)?
        private weak var scrollView: UIScrollView?
        private var observation: NSKeyValueObservation?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                self?.attachToNearestScrollView()
            }
        }

        private func attachToNearestScrollView() {
            guard let scroll = findScrollView(from: self) else { return }
            guard scroll !== scrollView else { return }
            scrollView = scroll
            observation = scroll.observe(\.contentOffset, options: [.new, .initial]) { [weak self] sv, _ in
                let adjustedTop = sv.adjustedContentInset.top
                let raw = sv.contentOffset.y + adjustedTop
                self?.onChange?(raw)
            }
        }

        private func findScrollView(from view: UIView) -> UIScrollView? {
            var current: UIView? = view.superview
            while let v = current {
                if let scroll = v as? UIScrollView { return scroll }
                // Also walk down once in case our probe is a sibling rather
                // than a descendant of the scroll view.
                if let found = scanDescendants(of: v) { return found }
                current = v.superview
            }
            return nil
        }

        private func scanDescendants(of view: UIView) -> UIScrollView? {
            for sub in view.subviews {
                if let scroll = sub as? UIScrollView { return scroll }
                if let found = scanDescendants(of: sub) { return found }
            }
            return nil
        }

        deinit {
            observation?.invalidate()
        }
    }
}

private struct PullToRefreshIndicator: View {
    let progress: Double
    let isRefreshing: Bool

    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.6))
                .frame(width: 48, height: 48)
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, y: 3)

            if isRefreshing {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
                    .onAppear { spin = true }
                    .onDisappear { spin = false }
            } else {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
            }
        }
        .scaleEffect(isRefreshing ? 1 : max(0.5, min(1, 0.5 + progress * 0.5)))
        .opacity(isRefreshing ? 1 : min(1, progress * 2))
    }
}
