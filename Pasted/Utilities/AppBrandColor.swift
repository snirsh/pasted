import SwiftUI

/// Returns a brand color for a known app bundle ID.
/// Used to color the banner in each clipboard card.
enum AppBrandColor {
    static func color(for bundleID: String?) -> Color {
        guard let id = bundleID?.lowercased() else { return .defaultBrand }
        switch true {
        // Browsers
        case id.contains("com.google.chrome"):        return Color(hex: 0x4285F4)
        case id.contains("com.apple.safari"):          return Color(hex: 0x006CFF)
        case id.contains("org.mozilla.firefox"):       return Color(hex: 0xFF6611)
        case id.contains("com.microsoft.edgemac"):     return Color(hex: 0x0078D7)
        case id.contains("com.operasoftware"):         return Color(hex: 0xFF1B2D)
        case id.contains("com.brave.browser"):         return Color(hex: 0xFB542B)
        // Communication
        case id.contains("com.tinyspeck.slackmacgap"): return Color(hex: 0x4A154B)
        case id.contains("com.microsoft.teams"):       return Color(hex: 0x5558AF)
        case id.contains("com.apple.messages"):        return Color(hex: 0x32D74B)
        case id.contains("ru.keepcoder.telegram"):     return Color(hex: 0x2CA5E0)
        case id.contains("com.whatsapp"):              return Color(hex: 0x25D366)
        case id.contains("com.hnc.discord"):           return Color(hex: 0x5865F2)
        case id.contains("com.mimestream"):            return Color(hex: 0x1C8DFF)
        case id.contains("com.apple.mail"):            return Color(hex: 0x1C8DFF)
        // Dev tools
        case id.contains("com.apple.dt.xcode"):        return Color(hex: 0x1575F9)
        case id.contains("com.microsoft.vscode"):      return Color(hex: 0x007ACC)
        case id.contains("com.jetbrains"):             return Color(hex: 0xFE315D)
        case id.contains("com.sublimetext"):           return Color(hex: 0xFF6C37)
        case id.contains("com.apple.terminal"):        return Color(hex: 0x2C2C2E)
        case id.contains("com.googlecode.iterm2"):     return Color(hex: 0x1A1A2E)
        case id.contains("com.github.atom"):           return Color(hex: 0x66595C)
        // Productivity
        case id.contains("com.apple.notes"):           return Color(hex: 0xFFD60A).darker()
        case id.contains("com.apple.finder"):          return Color(hex: 0x62A8F5)
        case id.contains("com.microsoft.word"):        return Color(hex: 0x2B579A)
        case id.contains("com.microsoft.excel"):       return Color(hex: 0x217346)
        case id.contains("com.microsoft.powerpoint"):  return Color(hex: 0xD24726)
        case id.contains("com.apple.iwork.pages"):     return Color(hex: 0xFF453A)
        case id.contains("com.apple.iwork.numbers"):   return Color(hex: 0x34C759)
        case id.contains("com.apple.iwork.keynote"):   return Color(hex: 0x0A84FF)
        case id.contains("com.notion"):                return Color(hex: 0x2F2F2F)
        case id.contains("com.figma"):                 return Color(hex: 0xF24E1E)
        case id.contains("com.adobe"):                 return Color(hex: 0xFF0000).opacity(0.85)
        // System / Pasted
        case id.contains("org.pasted"):               return Color(hex: 0x7B5EA7)
        default:                                       return .defaultBrand
        }
    }
}

private extension Color {
    static let defaultBrand = Color(hex: 0x3A3A4C)

    func darker(by amount: Double = 0.25) -> Color {
        let ui = NSColor(self)
        guard let rgb = ui.usingColorSpace(.sRGB) else { return self }
        return Color(
            red:   max(0, rgb.redComponent   - amount),
            green: max(0, rgb.greenComponent - amount),
            blue:  max(0, rgb.blueComponent  - amount)
        )
    }
}
