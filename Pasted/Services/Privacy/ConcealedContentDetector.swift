import AppKit

/// Detects clipboard content marked as sensitive via the `org.nspasteboard.ConcealedType`
/// community standard. Password managers (1Password, Bitwarden, KeePassXC, etc.) set this
/// flag to signal that clipboard managers should not persist the entry.
enum ConcealedContentDetector {
    /// The pasteboard type used by security-conscious apps to mark sensitive content.
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// Returns `true` if the pasteboard currently contains concealed (sensitive) content.
    ///
    /// Respects the `concealedDetectionEnabled` UserDefaults toggle. When the toggle
    /// is `false`, this method always returns `false` (detection disabled by user).
    static func isConcealed(_ pasteboard: NSPasteboard = .general) -> Bool {
        guard UserDefaults.standard.bool(forKey: "concealedDetectionEnabled") else {
            return false
        }
        return pasteboard.types?.contains(concealedType) == true
    }
}
