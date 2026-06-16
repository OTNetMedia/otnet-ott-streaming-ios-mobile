import SwiftUI

enum OTNetTheme {
    static let background    = Color(red: 0.04, green: 0.06, blue: 0.13)
    static let card          = Color(red: 0.07, green: 0.10, blue: 0.19)
    static let muted         = Color.white.opacity(0.06)
    static let border        = Color.white.opacity(0.10)
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let textTertiary  = Color.white.opacity(0.45)
    static let primary       = Color(red: 0.30, green: 0.40, blue: 1.0)

    static let cornerRadius: CGFloat       = 12
    static let heroCornerRadius: CGFloat   = 16
    static let rowGap: CGFloat             = 24
    static let cardGap: CGFloat            = 12
}
