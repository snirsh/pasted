import SwiftUI

/// Applies a background highlight colour to all occurrences of a query string
/// within the given text, returning an `AttributedString` for use with `Text`.
enum TextHighlighter {

    /// Returns an `AttributedString` with `highlightColor` applied as background
    /// to every case-insensitive occurrence of `query` in `text`.
    /// Returns a plain `AttributedString` if `query` is empty.
    static func highlight(_ text: String, query: String, highlightColor: Color) -> AttributedString {
        var attributed = AttributedString(text)
        guard !query.isEmpty else { return attributed }

        let lower = text.lowercased()
        let queryLower = query.lowercased()
        var searchFrom = lower.startIndex

        while let range = lower.range(of: queryLower, range: searchFrom..<lower.endIndex) {
            if let attrLower = AttributedString.Index(range.lowerBound, within: attributed),
               let attrUpper = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[attrLower..<attrUpper].backgroundColor = UIColorCompat.from(highlightColor)
            }
            searchFrom = range.upperBound
        }

        return attributed
    }
}

// MARK: - Platform shim

/// SwiftUI's AttributedString.backgroundColor expects an NSColor on macOS.
private enum UIColorCompat {
    static func from(_ color: Color) -> NSColor {
        NSColor(color)
    }
}
