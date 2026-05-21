import SwiftUI

// MARK: - Typography tokens
// Design direction: "WorldTracker Colorful / Vibrant & Elegant"
//   • Editorial / display — Fraunces italic variable font
//     PostScript name: "Fraunces-9ptBlackItalic"
//   • UI / body           — Inter variable font (wght axis)
//     PostScript name: "Inter-Regular"
//
// Font files in Resources/Fonts/:
//   Fraunces-Italic-VariableFont_SOFT,WONK,opsz,wght.ttf
//   Inter-VariableFont_opsz,wght.ttf

private enum FontName {
    static let fraunces = "Fraunces-9ptBlackItalic"
    static let inter    = "Inter-Regular"
}

// MARK: - AppTypography
enum AppTypography {

    // MARK: Display / Editorial  (Fraunces italic)

    /// Massive serif italic — hero stat numbers (≈90 pt)
    static let displayHero   = Font.custom(FontName.fraunces, size: 90, relativeTo: .largeTitle)

    /// Large serif italic — section hero / big callout (≈44 pt)
    static let displayLarge  = Font.custom(FontName.fraunces, size: 44, relativeTo: .largeTitle)

    /// Medium serif italic — card headings / country names (≈28 pt)
    static let displayMedium = Font.custom(FontName.fraunces, size: 28, relativeTo: .title)

    /// Small serif italic — inline editorial accents (≈19 pt)
    static let displaySmall  = Font.custom(FontName.fraunces, size: 19, relativeTo: .title2)

    // MARK: Screen Titles

    /// Primary screen / section title (≈26 pt)
    static let screenTitle   = Font.custom(FontName.fraunces, size: 26, relativeTo: .title)

    // MARK: Stat Numbers

    /// Large stat number (≈34 pt) — upright regular serif
    static let statLarge     = Font.system(size: 34, weight: .regular, design: .serif)

    /// Small stat number (≈24 pt) — upright regular serif
    static let statSmall     = Font.system(size: 24, weight: .regular, design: .serif)

    // MARK: Body / UI  (Inter — weight via .weight() activates wght axis)

    /// Standard body text (15 pt)
    static let body          = Font.custom(FontName.inter, size: 15, relativeTo: .body)

    /// Secondary / caption body (13 pt)
    static let bodySmall     = Font.custom(FontName.inter, size: 13, relativeTo: .subheadline)

    /// Caption / card label (13 pt bold)
    static let caption       = Font.custom(FontName.inter, size: 13, relativeTo: .subheadline).weight(.bold)

    // MARK: Section Label / Eyebrow
    static let eyebrow       = Font.custom(FontName.inter, size: 10, relativeTo: .caption2).weight(.bold)

    // MARK: Labels / Buttons

    /// Medium-weight label (14 pt)
    static let label         = Font.custom(FontName.inter, size: 14, relativeTo: .callout)

    /// Semi-bold label (14 pt)
    static let labelSemiBold = Font.custom(FontName.inter, size: 14, relativeTo: .callout).weight(.semibold)

    /// Bold button / CTA label (15 pt)
    static let buttonLabel   = Font.custom(FontName.inter, size: 15, relativeTo: .body).weight(.bold)
}

// MARK: - Convenience modifiers

extension View {

    /// Applies the standard eyebrow / section-label style:
    /// 10 pt Inter SemiBold · uppercase · +2.2 tracking · `appInk3` foreground.
    func eyebrowStyle(color: Color = .appInk3) -> some View {
        self
            .font(AppTypography.eyebrow)
            .textCase(.uppercase)
            .tracking(2.2)
            .foregroundStyle(color)
    }
}
