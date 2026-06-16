import SwiftUI

@main
struct OTNetApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(
                epgEnabled: true,
                myListEnabled: true,
                viewerAuthNone: false
            )
        }
    }
}
