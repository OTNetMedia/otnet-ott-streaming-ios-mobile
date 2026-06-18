import SwiftUI

/// Detail-page primary action when the title is paywalled. Mirrors the
/// website's `PaywallCTA` label logic (Subscribe / Buy for £X / Rent for
/// £X · Nh) so the price is visible at the place the user decides whether
/// to commit, not just after they tap Play and hit a 402.
struct PaywallCTAButton: View {
    let paywall: PaywallInfo?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(paywall?.ctaLabel ?? "Subscribe to watch")
                    .font(.body.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(OTNetTheme.primary, in: Capsule())
            .shadow(color: OTNetTheme.primary.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
