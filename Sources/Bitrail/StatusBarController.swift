import AppKit
import SwiftUI
import Combine

final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let state: PlaybackState
    private var cancellable: AnyCancellable?
    private let popover = NSPopover()

    init(state: PlaybackState) {
        self.state = state
        super.init()

        popover.behavior = .transient
        popover.delegate = self

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
        }

        render()
        cancellable = state.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.render() }
        }
    }

    var onToggleAutoSwitch: (() -> Void)?
    var onQuit: (() -> Void)?

    private func render() {
        guard let button = statusItem.button else { return }
        button.image = statusBarSymbol
        button.image?.isTemplate = false
        button.title = statusBarLabel
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        let hostingController = NSHostingController(
            rootView: PopoverContentView(
                state: state,
                onToggleAutoSwitch: { [weak self] in self?.onToggleAutoSwitch?() },
                onQuit: { [weak self] in self?.onQuit?() }
            )
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
    }

    private var statusBarSymbol: NSImage? {
        let name: String
        let color: NSColor
        if let tier = state.qualityTier {
            name = tier.symbolName
            color = NSColor(tier.tint)
        } else {
            name = state.transport.symbolName
            color = .secondaryLabelColor
        }
        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    private var statusBarLabel: String {
        if let tier = state.qualityTier, let sr = state.sourceSampleRate, let bd = state.sourceBitDepth {
            let mismatch = state.hasRateMismatch ? " !" : ""
            return String(format: " %.0fkHz/%dbit%@", sr / 1000, bd, mismatch) + " \(tier == .hiRes ? "HiRes" : tier.rawValue)"
        }
        if state.transport == .bluetooth, let codec = state.bluetoothCodec, let rate = state.bluetoothCodecSampleRate {
            return String(format: " %@ %.0fkHz", codec, rate / 1000)
        }
        if let sr = state.liveSampleRate {
            return String(format: " %.0fkHz", sr / 1000)
        }
        return " Bitrail"
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
