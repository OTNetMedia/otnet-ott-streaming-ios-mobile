import SafariServices
import SwiftUI

/// Thin SFSafariViewController bridge so we can present a hosted Stripe
/// Checkout page in-app, with shared cookies / autofill but a clear way back
/// to our UI when the viewer hits Done.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .done
        vc.modalPresentationStyle = .pageSheet
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: (() -> Void)?
        init(onDismiss: (() -> Void)?) { self.onDismiss = onDismiss }

        // Fires when the viewer taps Done. SFSafariViewController exposes no
        // public mid-navigation hook (Apple intentionally keeps post-load
        // navigations private), so this is the only signal we get back from
        // the Stripe checkout flow.
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss?()
        }
    }
}
