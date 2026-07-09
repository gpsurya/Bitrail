import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon, menu bar only
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Without this, the out-of-process perl helper mediaremote-adapter
        // spawns for now-playing info is left orphaned when Bitrail quits.
        coordinator.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
