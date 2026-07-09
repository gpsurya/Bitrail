import AppKit

// The actual installed app's real icon (via Launch Services), not a generic
// SF Symbol placeholder - there's no need to guess/hand-maintain a mapping
// of "which icon looks like Spotify" when macOS already has the real one.
// Works even when the app isn't the frontmost app, since it looks up by
// bundle identifier via Launch Services rather than the running process list.
enum AppIconProvider {
    private static var cache = [String: NSImage]()

    static func icon(forBundleIdentifier bundleIdentifier: String?) -> NSImage? {
        guard let bundleIdentifier else { return nil }
        if let cached = cache[bundleIdentifier] { return cached }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleIdentifier] = icon
        return icon
    }
}
