import AppKit

/// Caches NSImage app icons looked up by bundle ID.
/// Fetching via NSWorkspace is synchronous and somewhat expensive, so we
/// cache the result keyed by bundle ID and never re-fetch.
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]

    private init() {}

    func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = cache[bundleID] { return cached }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: appURL.path)
        cache[bundleID] = image
        return image
    }
}
