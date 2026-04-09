import SwiftUI

/// Centralised design constants for the Pasted app.
/// Use these instead of inline magic numbers so changes propagate everywhere.
enum DesignTokens {

    // MARK: - Colors

    enum Colors {
        // Content-type accent colors (used in banners, badges, icons)
        static let textType     = Color(hex: 0x0060FF) // blue
        static let richTextType = Color(hex: 0x10B981) // emerald
        static let imageType    = Color(hex: 0x7C3AED) // purple
        static let urlType      = Color(hex: 0x5AC8FA) // sky blue
        static let fileType     = Color(hex: 0xF59E0B) // amber
        static let colorType    = Color(hex: 0xEC4899) // pink

        // Selection highlight
        static let selectionBorder    = Color(hex: 0x3B71F2)
        static let selectionFill      = Color(hex: 0x3B71F2).opacity(0.15)

        // Search match highlight
        static let searchHighlight    = Color.yellow.opacity(0.45)

        // Checkerboard (image transparency indicator) — light mode
        static let checkerLightA = Color(hex: 0xFFFFFF)
        static let checkerLightB = Color(hex: 0xE5E5E5)
        // Checkerboard — dark mode
        static let checkerDarkA  = Color(hex: 0x3A3A3A)
        static let checkerDarkB  = Color(hex: 0x4A4A4A)

        // Card content area background
        static let cardContentBg  = Color(red: 0.13, green: 0.13, blue: 0.15)
        static let cardFooterBg   = Color(red: 0.16, green: 0.16, blue: 0.18)
    }

    // MARK: - Typography

    enum Typography {
        static let bannerTitle  = Font.system(size: 15, weight: .semibold)
        static let bannerSub    = Font.system(size: 11, weight: .regular)
        static let cardBody     = Font.system(size: 13)
        static let cardMono     = Font.system(size: 13, design: .monospaced)
        static let cardBadge    = Font.system(size: 11)
        static let cardBadgeMed = Font.system(size: 11, weight: .medium)
        static let metadata     = Font.system(size: 11)
        static let metadataMono = Font.system(size: 11, design: .monospaced)
        static let timestamp    = Font.system(size: 10)
        static let detailTitle  = Font.system(size: 16, weight: .semibold)
        static let detailMono   = Font.system(size: 13, design: .monospaced)
    }

    // MARK: - Layout

    enum Layout {
        static let cardCornerRadius:     CGFloat = 10
        static let stripCornerRadius:    CGFloat = 12
        static let panelCornerRadius:    CGFloat = 16
        static let cardPadding:          CGFloat = 10
        static let cardSpacing:          CGFloat = 10
        static let cardBaseWidth:        CGFloat = 200
        static let cardBaseHeight:       CGFloat = 240
        static let bannerHeight:         CGFloat = 56
        static let footerHeight:         CGFloat = 30
        static let checkerboardCellSize: CGFloat = 8
        static let selectionBorderWidth: CGFloat = 3
        static let stripTopOffset:       CGFloat = 48
        static let previewModalWidth:    CGFloat = 480
        static let previewModalHeight:   CGFloat = 360
        static let appIconSize:          CGFloat = 40
        static let appIconCornerRadius:  CGFloat = 9
    }

    // MARK: - Animation

    enum Animation {
        static let stripShow    = SwiftUI.Animation.easeOut(duration: 0.15)
        static let stripHide    = SwiftUI.Animation.easeIn(duration: 0.12)
        static let previewShow  = SwiftUI.Animation.easeOut(duration: 0.15)
        static let previewHide  = SwiftUI.Animation.easeIn(duration: 0.12)
        static let navScroll    = SwiftUI.Animation.easeInOut(duration: 0.15)
    }
}

// MARK: - Color hex initialisers (available app-wide)

extension Color {
    /// Initialise from a 24-bit hex integer, e.g. `Color(hex: 0xFF6600)`.
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }

    /// Initialise from a hex string like `"#FF6600"` or `"FF6600"`.
    /// Returns `nil` if the string cannot be parsed.
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
