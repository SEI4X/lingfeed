import SwiftUI

enum AppTheme {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.06, blue: 0.065, alpha: 1)
            : UIColor(red: 0.93, green: 0.925, blue: 0.905, alpha: 1)
    })

    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.115, green: 0.115, blue: 0.12, alpha: 1)
            : UIColor(red: 0.985, green: 0.982, blue: 0.965, alpha: 1)
    })

    static let recessed = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
            : UIColor(red: 0.945, green: 0.94, blue: 0.915, alpha: 1)
    })

    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.94, blue: 0.92, alpha: 1)
            : UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    })

    static let muted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.58, blue: 0.58, alpha: 1)
            : UIColor(red: 0.46, green: 0.47, blue: 0.50, alpha: 1)
    })

    static let hairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.26, green: 0.26, blue: 0.27, alpha: 1)
            : UIColor(red: 0.80, green: 0.78, blue: 0.72, alpha: 1)
    })

    static let action = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.94, blue: 0.92, alpha: 1)
            : UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    })

    static let actionText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
            : UIColor.white
    })

    static let accent = Color(red: 0.27, green: 0.34, blue: 0.95)
    static let success = Color(red: 0.15, green: 0.49, blue: 0.31)
    static let danger = Color(red: 0.85, green: 0.18, blue: 0.22)
    static let cardRadius: CGFloat = 26
    static let controlRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 17

    static var eyebrowFont: Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }

    static var bodyMonoFont: Font {
        .system(size: 13, weight: .medium, design: .monospaced)
    }
}

struct SurfaceModifier: ViewModifier {
    var fill: Color = AppTheme.surface
    var border: Color = AppTheme.hairline
    var radius: CGFloat = AppTheme.controlRadius
    var shadow: Bool = false

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(0.42), lineWidth: 0.7)
                    .blendMode(.overlay)
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border.opacity(0.62), lineWidth: 0.7)
            )
            .shadow(color: shadow ? .black.opacity(0.08) : .clear, radius: 18, x: 0, y: 10)
    }
}

extension View {
    func appSurface(
        fill: Color = AppTheme.surface,
        border: Color = AppTheme.hairline,
        radius: CGFloat = AppTheme.controlRadius,
        shadow: Bool = false
    ) -> some View {
        modifier(SurfaceModifier(fill: fill, border: border, radius: radius, shadow: shadow))
    }
}
