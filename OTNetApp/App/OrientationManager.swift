import SwiftUI
import UIKit

/// Lets individual screens override which interface orientations are allowed.
/// The AppDelegate consults this when iOS asks for supported orientations.
final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    private(set) var mask: UIInterfaceOrientationMask = .portrait
    private init() {}

    func lock(_ mask: UIInterfaceOrientationMask, rotateTo: UIInterfaceOrientation? = nil) {
        self.mask = mask
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            let orientations: UIInterfaceOrientationMask = {
                guard let rotateTo else { return mask }
                switch rotateTo {
                case .landscapeLeft: return .landscapeLeft
                case .landscapeRight: return .landscapeRight
                case .portraitUpsideDown: return .portraitUpsideDown
                default: return .portrait
                }
            }()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationManager.shared.mask
    }
}

extension View {
    /// Lock orientation while this view is on screen, then restore to `restoreTo`
    /// when it goes away.
    func lockOrientation(to mask: UIInterfaceOrientationMask,
                         rotateTo: UIInterfaceOrientation? = nil,
                         restoreTo: UIInterfaceOrientationMask = .portrait) -> some View {
        self
            .onAppear { OrientationManager.shared.lock(mask, rotateTo: rotateTo) }
            .onDisappear { OrientationManager.shared.lock(restoreTo) }
    }
}
