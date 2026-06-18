import SwiftUI
import UIKit

/// Friendly takeover for a 402 Payment Required when the viewer tries to
/// play a title they can't watch. Mirrors the labels the web `PaywallCTA`
/// component uses (lib/types.ts → PaywallBlock).
struct PaywallSurface: View {
    let content: Content
    let info: PaywallInfo?
    let onDismiss: () -> Void
    /// Fires when we've confirmed (via a re-fetch of /catalog/content/:id)
    /// that the title is now entitled after the viewer returns from Stripe.
    /// The caller should dismiss the paywall and re-launch playback.
    var onPurchaseConfirmed: (() -> Void)? = nil

    @EnvironmentObject private var auth: AuthStore
    @State private var checkoutURL: URL?
    @State private var isStartingCheckout = false
    @State private var isVerifyingPurchase = false
    @State private var checkoutError: String?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                backdrop(width: geo.size.width, height: geo.size.height)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    card
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(40, geo.safeAreaInsets.bottom + 24))
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)

                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.55), in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, max(16, geo.safeAreaInsets.top + 4))
                .frame(width: geo.size.width, alignment: .topTrailing)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .background(OTNetTheme.background)
        .ignoresSafeArea()
        .sheet(item: Binding(
            get: { checkoutURL.map(IdentifiableURL.init) },
            set: { checkoutURL = $0?.url }
        )) { identifiable in
            SafariView(url: identifiable.url, onDismiss: {
                checkoutURL = nil
                verifyPurchaseAfterReturn()
            })
            .ignoresSafeArea()
        }
        .overlay {
            if isVerifyingPurchase {
                verifyingOverlay
            }
        }
    }

    private var verifyingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).scaleEffect(1.3)
                Text("Confirming your purchase…")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(OTNetTheme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .transition(.opacity)
    }

    private struct IdentifiableURL: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private func backdrop(width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: content.backdropURL ?? content.landscapeURL ?? content.posterURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            default:
                Rectangle().fill(OTNetTheme.card)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.25),
                    Color.black.opacity(0.55),
                    OTNetTheme.background
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: width, height: height)
        )
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(OTNetTheme.primary)
                Text(headline.uppercased())
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(OTNetTheme.primary)
            }

            Text(content.displayTitle)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let body = bodyText {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let planNames = info?.detail?.planNames, !planNames.isEmpty {
                planList(planNames)
            }

            if let checkoutError {
                Text(checkoutError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                Button(action: handleCTA) {
                    HStack {
                        if isStartingCheckout {
                            ProgressView().tint(.white)
                        }
                        Text(info?.ctaLabel ?? "Subscribe to watch")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(OTNetTheme.primary.opacity(isStartingCheckout ? 0.7 : 1),
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isStartingCheckout)

                Button(action: onDismiss) {
                    Text("Not now")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(OTNetTheme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }

    private var headline: String {
        info?.headline ?? "Subscription required"
    }

    private var bodyText: String? {
        if let d = info?.description, !d.isEmpty { return d }
        switch info?.reason {
        case "signin_required":
            return "Sign in to watch this title."
        case "wrong_plan":
            if let current = info?.detail?.currentPlan, !current.isEmpty {
                return "You're on \(current). This title needs a different plan."
            }
            return "This title needs a different subscription plan."
        case "expired":
            return "Your rental window has ended. Rent again to keep watching."
        case "not_purchased":
            return info?.mode == "rental"
                ? "Rent this title to start watching."
                : "Buy this title to start watching."
        case "no_subscription", .none, .some(_):
            return "This title is part of a subscription. Sign up to unlock it."
        }
    }

    @ViewBuilder
    private func planList(_ names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Available on")
                .font(.caption.bold())
                .foregroundStyle(OTNetTheme.textTertiary)
            FlowLayoutChips(names: names)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleCTA() {
        // signin_required can't go through Stripe — the server expects a
        // viewer Bearer to mint a checkout session. Surface a clear hint.
        if info?.reason == "signin_required" || !auth.isSignedIn {
            checkoutError = "Sign in to continue with checkout."
            return
        }
        checkoutError = nil
        isStartingCheckout = true
        Task {
            defer { Task { @MainActor in isStartingCheckout = false } }
            do {
                let planName = info?.detail?.planNames?.first
                // The success/cancel URLs are what Stripe will redirect to
                // after checkout. Use the OTNet homepage as a known-working
                // landing page — we re-verify entitlement in-app the moment
                // Safari is dismissed, so the page contents don't matter.
                let resp = try await OTNetAPI.shared.startCheckout(
                    contentId: content.id,
                    planName: planName,
                    successUrl: "https://otnet.io/",
                    cancelUrl:  "https://otnet.io/"
                )
                guard let urlStr = resp.url, let url = URL(string: urlStr) else {
                    await MainActor.run {
                        checkoutError = "Couldn't start checkout. Please try again."
                    }
                    return
                }
                await MainActor.run { checkoutURL = url }
            } catch {
                await MainActor.run {
                    checkoutError = "Couldn't start checkout: \(error.localizedDescription)"
                }
            }
        }
    }

    /// After the viewer closes Safari, re-fetch the content a few times
    /// (Stripe → OTNet webhook latency can take a beat) and signal success
    /// the moment `entitled` flips to true. If it doesn't flip within ~4s,
    /// surface a soft hint and let the user try again.
    private func verifyPurchaseAfterReturn() {
        guard onPurchaseConfirmed != nil else { return }
        isVerifyingPurchase = true
        checkoutError = nil
        Task {
            for attempt in 0..<5 {
                if attempt > 0 {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
                do {
                    let refreshed = try await OTNetAPI.shared.content(id: content.id)
                    if refreshed.entitled == true {
                        await MainActor.run {
                            isVerifyingPurchase = false
                            onPurchaseConfirmed?()
                        }
                        return
                    }
                } catch {
                    DebugProbe.log("verify after checkout failed (attempt \(attempt)): \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                isVerifyingPurchase = false
                checkoutError = "We couldn't confirm your payment just yet. If it went through, tap the CTA again in a moment."
            }
        }
    }
}

/// Wrap chips onto multiple lines so a long plan list doesn't push the card
/// past the screen width.
private struct FlowLayoutChips: View {
    let names: [String]

    var body: some View {
        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(names, id: \.self) { chip($0) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(names, id: \.self) { chip($0) }
                }
            }
        } else {
            HStack(spacing: 6) {
                ForEach(names.prefix(3), id: \.self) { chip($0) }
            }
        }
    }

    private func chip(_ name: String) -> some View {
        Text(name)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.1), in: Capsule())
    }
}
