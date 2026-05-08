import SwiftUI

// MARK: - Color tokens

extension Color {

    // MARK: Surfaces
    static let appPaper  = Color(hex: "#F7F7F7")
    static let appPaper2 = Color(hex: "#F3F3F3")
    static let appCard   = Color.white

    // MARK: Ink / Text
    static let appInk    = Color(hex: "#1b1b1b")
    static let appInk2   = Color(hex: "#6B6B6B")
    static let appInk3   = Color(hex: "#9E9E9E")

    // MARK: Borders
    static let appLine   = Color(hex: "#E2E2E2")

    // MARK: Visited (cherry red — matches map fill)
    static let appVisited    = Color(hex: "#DC2626")
    static let appVisitedBg  = Color(hex: "#FEF2F2")

    // MARK: Wishlist (vivid violet — matches map fill)
    static let appWishlist   = Color(hex: "#7C3AED")
    static let appWishlistBg = Color(hex: "#F5F3FF")

    // MARK: Achievement (gold)
    static let appGold   = Color(hex: "#E6A817")
    static let appGoldBg = Color(hex: "#FFF9E6")

    // MARK: Success / confirmed (green)
    static let appSuccess   = Color(hex: "#2E9E5B")
    static let appSuccessBg = Color(hex: "#F0FFF4")
}

// MARK: - Hex initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
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
