import Foundation

/// Heuristic-based detector that decides whether a string looks like source code.
/// Used to switch clipboard text cards to monospaced font.
enum CodeDetector {

    /// Keywords / symbols that strongly indicate source code.
    private static let strongSignals: [String] = [
        "func ", "def ", "class ", "import ", "const ", "export "
    ]

    /// Weaker symbols — two or more of these together indicates code.
    private static let weakSignals: [String] = [
        "var ", "let ", "=>", "->", "//", "/*", "*/", "};", ");",
        "{", "}", "()", "[]", "==="
    ]

    /// Returns `true` if `text` looks like source code.
    /// Detection: 1 strong signal OR 2+ weak signals.
    static func isCode(_ text: String) -> Bool {
        guard text.count > 5 else { return false }

        for signal in strongSignals {
            if text.contains(signal) { return true }
        }

        var weakCount = 0
        for signal in weakSignals {
            if text.contains(signal) {
                weakCount += 1
                if weakCount >= 2 { return true }
            }
        }

        return false
    }
}
