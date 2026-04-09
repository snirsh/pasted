import Foundation

/// Hardcoded list of password managers and security apps excluded by default.
/// Updated with each Pasted release. No network calls (Privacy-First principle).
enum DefaultExclusionList {
    /// Default apps to exclude, identified by bundle ID and human-readable name.
    static let entries: [(bundleID: String, displayName: String)] = [
        ("com.1password.1password", "1Password 8"),
        ("com.agilebits.onepassword7", "1Password 7"),
        ("com.bitwarden.desktop", "Bitwarden"),
        ("com.lastpass.LastPass", "LastPass"),
        ("org.keepassxc.keepassxc", "KeePassXC"),
        ("com.getdashlane.dashlane", "Dashlane"),
        ("com.apple.keychainaccess", "Keychain Access"),
        ("in.sinew.Enpass-Desktop", "Enpass"),
        ("com.nickvdp.Secrets", "Secrets"),
    ]

    /// Set of all default bundle identifiers for O(1) membership checks.
    static var bundleIdentifiers: Set<String> {
        Set(entries.map(\.bundleID))
    }
}
