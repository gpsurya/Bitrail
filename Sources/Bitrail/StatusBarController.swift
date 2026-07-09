import AppKit
import SwiftUI
import Combine

final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let state: PlaybackState
    private var cancellable: AnyCancellable?
    private let popover = NSPopover()
    private let hostingController: NSHostingController<PopoverContentView>

    // Cached against the last rendered values so we only touch the button/popover
    // when something actually displayed changes - AppKit visibly resizes/reflows
    // the status item and popover on every touch, so redundant writes on every
    // 2s poll tick were showing up as a right-to-left "flicker".
    private var lastRenderedLabel: String?
    private var lastRenderedSymbolName: String?

    init(state: PlaybackState) {
        self.state = state
        self.hostingController = NSHostingController(
            rootView: PopoverContentView(state: state, onToggleAutoSwitch: {}, onQuit: {})
        )
        super.init()

        hostingController.sizingOptions = [.preferredContentSize]
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = hostingController

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.action = #selector(togglePopover)
            button.target = self
        }

        render()
        // A single logical update (e.g. "device connected") writes several
        // @Published properties in a row, each firing objectWillChange
        // separately. Coalesce bursts on the same run loop pass into one
        // render() instead of one per property.
        cancellable = state.objectWillChange
            .collect(.byTime(RunLoop.main, .milliseconds(50)))
            .sink { [weak self] _ in self?.render() }
    }

    var onToggleAutoSwitch: (() -> Void)?
    var onQuit: (() -> Void)?

    private func render() {
        guard let button = statusItem.button else { return }

        let symbolName = state.qualityTier?.symbolName ?? state.deviceCategory.symbolName
        if symbolName != lastRenderedSymbolName {
            lastRenderedSymbolName = symbolName
            button.image = statusBarSymbol
            button.image?.isTemplate = false
        }

        let label = statusBarLabel
        if label != lastRenderedLabel {
            lastRenderedLabel = label
            button.title = label
        }

        // SwiftUI diffs the view tree itself - reassigning rootView with the
        // same @ObservedObject reference does not force a fresh layout/animation,
        // it only re-renders whatever text/state actually differs.
        hostingController.rootView = PopoverContentView(
            state: state,
            onToggleAutoSwitch: { [weak self] in self?.onToggleAutoSwitch?() },
            onQuit: { [weak self] in self?.onQuit?() }
        )
    }

    private var statusBarSymbol: NSImage? {
        let name: String
        let color: NSColor
        if let tier = state.qualityTier {
            name = tier.symbolName
            color = NSColor(tier.tint)
        } else {
            name = state.deviceCategory.symbolName
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
