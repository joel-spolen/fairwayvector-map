import SwiftUI

/// Presentation-only palette for the experimental home, course and handicap screens.
/// Deliberately separate from the shared Practice design system.
enum PureLineStyle {
    static let accent = Color(red: 0.0, green: 0.49, blue: 0.45)
    static let ink = Color(red: 0.10, green: 0.15, blue: 0.16)
    static let muted = Color(red: 0.40, green: 0.46, blue: 0.47)
    static let canvas = Color.white
    static let surface = Color(red: 0.96, green: 0.98, blue: 0.98)
    static let line = Color(red: 0.88, green: 0.92, blue: 0.91)
}

extension View {
    func pureLineCard(padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .background(PureLineStyle.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(PureLineStyle.line.opacity(0.6), lineWidth: 1)
            }
    }
}

struct PureLinePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(PureLineStyle.accent, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}