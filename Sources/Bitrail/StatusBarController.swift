import AppKit
import Combine

final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let state: PlaybackState
    private var cancellable: AnyCancellable?
    private let menu = NSMenu()

    init(state: PlaybackState) {
        self.state = state
        statusItem.menu = menu
        render()
        cancellable = state.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.render() }
        }
    }

    private func render() {
        statusItem.button?.title = state.statusBarText

        menu.removeAllItems()
        menu.addItem(withTitle: state.appName ?? "No app playing", action: nil, keyEquivalent: "")
        if let title = state.trackTitle {
            let subtitle = [title, state.trackArtist].compactMap { $0 }.joined(separator: " — ")
            menu.addItem(withTitle: subtitle, action: nil, keyEquivalent: "")
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Device: \(state.deviceName ?? "Unknown") (\(state.transport.rawValue))", action: nil, keyEquivalent: "")

        if state.transport == .bluetooth {
            if let codec = state.bluetoothCodec, let rate = state.bluetoothCodecSampleRate {
                menu.addItem(withTitle: String(format: "Codec: %@ @ %.1fkHz", codec, rate / 1000), action: nil, keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Codec: detecting…", action: nil, keyEquivalent: "")
            }
        }

        if let sourceSampleRate = state.sourceSampleRate {
            let detected = String(format: "Detected (source): %.1fkHz/%dbit", sourceSampleRate / 1000, state.sourceBitDepth ?? 0)
            menu.addItem(withTitle: detected, action: nil, keyEquivalent: "")
        }
        if let liveSampleRate = state.liveSampleRate {
            let actualTitle = state.hasRateMismatch ? "Actual (device): %.1fkHz ⚠︎ mismatch" : "Actual (device): %.1fkHz"
            menu.addItem(withTitle: String(format: actualTitle, liveSampleRate / 1000), action: nil, keyEquivalent: "")
        }

        if state.transport == .wired {
            let toggle = NSMenuItem(title: "Auto-match sample rate", action: #selector(toggleAutoSwitch), keyEquivalent: "")
            toggle.target = self
            toggle.state = state.autoSwitchEnabled ? .on : .off
            menu.addItem(toggle)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Bitrail", action: #selector(quit), keyEquivalent: "q")
    }

    @objc private func toggleAutoSwitch() {
        state.autoSwitchEnabled.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
