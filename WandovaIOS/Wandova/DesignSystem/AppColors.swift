import SwiftUI

// MARK: - Adaptive Color Tokens

extension Color {

    // MARK: Surfaces
    static let appPaper  = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#1A1A1A") : UIColor(hex: "#F7F7F7")
    })
    static let appPaper2 = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#2A2A2A") : UIColor(hex: "#F3F3F3")
    })
    static let appCard = Color(UIColor.secondarySystemGroupedBackground)

    // MARK: Ink / Text
    static let appInk  = Color(UIColor.label)
    static let appInk2 = Color(UIColor.secondaryLabel)
    static let appInk3 = Color(UIColor.tertiaryLabel)

    // MARK: Borders / Dividers
    static let appLine = Color(UIColor.separator)

    // MARK: Intentional dark surface (hero cards, CTAs) — elevated in dark mode
    static let appSurface = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#2C2C2E") : UIColor(hex: "#111111")
    })

    // MARK: Visited (cherry red — matches map fill)
    static let appVisited   = Color(hex: "#DC2626")
    static let appVisitedBg = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#3D1515") : UIColor(hex: "#FEF2F2")
    })

    // MARK: Wishlist (vivid violet — matches map fill)
    static let appWishlist   = Color(hex: "#7C3AED")
    static let appWishlistBg = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#2D1B4E") : UIColor(hex: "#F5F3FF")
    })

    // MARK: Achievement (gold)
    static let appGold   = Color(hex: "#E6A817")
    static let appGoldBg = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#3D2D0A") : UIColor(hex: "#FFF9E6")
    })

    // MARK: Success / confirmed (green)
    static let appSuccess   = Color(hex: "#2E9E5B")
    static let appSuccessBg = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#0D3320") : UIColor(hex: "#F0FFF4")
    })
}

// MARK: - Hex initializer (SwiftUI Color)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Hex initializer (UIColor — used in dynamic color providers above)
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}
