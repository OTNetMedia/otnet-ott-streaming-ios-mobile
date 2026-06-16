import SwiftUI

// MARK: - Press feedback

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var opacity: Double = 0.85
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Play

struct PlayButton: View {
    enum Size { case regular, compact }

    var title: String = "Play"
    var size: Size = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: spacing) {
                ZStack {
                    Circle().fill(.black.opacity(0.18))
                        .frame(width: iconBg, height: iconBg)
                    Image(systemName: "play.fill")
                        .font(.system(size: iconSize, weight: .black))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                }
                Text(title)
                    .font(.system(size: textSize, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background(
                LinearGradient(
                    colors: [OTNetTheme.primary, OTNetTheme.primary.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                ),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: OTNetTheme.primary.opacity(0.45), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var iconBg: CGFloat { size == .compact ? 22 : 26 }
    private var iconSize: CGFloat { size == .compact ? 11 : 13 }
    private var textSize: CGFloat { size == .compact ? 14 : 16 }
    private var spacing: CGFloat { size == .compact ? 8 : 10 }
    private var hPadding: CGFloat { size == .compact ? 16 : 22 }
    private var vPadding: CGFloat { size == .compact ? 10 : 13 }
}

// MARK: - My List

struct MyListButton: View {
    enum Size { case regular, compact }

    let isInList: Bool
    let isPending: Bool
    var size: Size = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: spacing) {
                ZStack {
                    if isPending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isInList ? "checkmark" : "plus")
                            .font(.system(size: iconSize, weight: .black))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                            .id(isInList)
                    }
                }
                .frame(width: iconBg, height: iconBg)

                Text(isInList ? "My List" : "My List")
                    .font(.system(size: textSize, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background(
                Capsule()
                    .fill(isInList
                          ? AnyShapeStyle(.ultraThinMaterial.opacity(0.7))
                          : AnyShapeStyle(.ultraThinMaterial.opacity(0.45)))
            )
            .overlay(
                Capsule()
                    .stroke(isInList ? OTNetTheme.primary.opacity(0.75) : .white.opacity(0.22),
                            lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isInList)
    }

    private var iconBg: CGFloat { size == .compact ? 18 : 22 }
    private var iconSize: CGFloat { size == .compact ? 12 : 14 }
    private var textSize: CGFloat { size == .compact ? 14 : 16 }
    private var spacing: CGFloat { size == .compact ? 7 : 9 }
    private var hPadding: CGFloat { size == .compact ? 16 : 22 }
    private var vPadding: CGFloat { size == .compact ? 10 : 13 }
}
