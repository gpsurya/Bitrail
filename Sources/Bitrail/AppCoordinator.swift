import Foundation
import AppKit

final class AppCoordinator {
    private let state = PlaybackState()
    private let nowPlaying = NowPlayingSource()
    private let outputMonitor = OutputDeviceMonitor()
    private var statusBar: StatusBarController?
    private var pollTimer: Timer?

    // BluetoothCodecDetector scans a wide (hours-long) log window since the
    // negotiation log line only appears once per connection, not
    // periodically. That's expensive to run on every 2s poll tick forever if
    // detection genuinely fails (e.g. unexpected log wording) - cap retries
    // per connection instead of hammering the log store indefinitely.
    private var bluetoothDetectionAttempts = 0
    private let maxBluetoothDetectionAttempts = 5

    func start() {
        let bar = StatusBarController(state: state)
        bar.onToggleAutoSwitch = { [weak self] in self?.state.autoSwitchEnabled.toggle() }
        bar.onQuit = { NSApp.terminate(nil) }
        statusBar = bar

        outputMonitor.onChange = { [weak self] in self?.refreshDevice() }
        refreshDevice()

        nowPlaying.onTrackChanged = { [weak self] info in
            guard let self else { return }
            // MediaController streams updates continuously (elapsed time, playback
            // rate, etc.), not just on actual track changes - guard against
            // rewriting identical values, which was flooding objectWillChange and
            // causing the status bar/popover to visibly reflow every update.
            let trackActuallyChanged = self.state.appName != info?.appName
                || self.state.trackTitle != info?.title
                || self.state.trackArtist != info?.artist
            guard trackActuallyChanged else { return }

            self.state.appName = info?.appName
            self.state.trackTitle = info?.title
            self.state.trackArtist = info?.artist
            self.handleTrackChange()
        }
        nowPlaying.start()

        // Apple Music doesn't push format changes, so poll while it's the active app.
        // Bluetooth codec is negotiated once per connection, so poll less often.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshDevice()
            if self.state.appName == "Music" {
                self.detectAppleMusicQuality()
            }
            if self.state.transport == .bluetooth, self.state.bluetoothCodec == nil,
               self.bluetoothDetectionAttempts < self.maxBluetoothDetectionAttempts {
                self.bluetoothDetectionAttempts += 1
                self.detectBluetoothCodec()
            }
        }
    }

    private func handleTrackChange() {
        if state.sourceSampleRate != nil { state.sourceSampleRate = nil }
        if state.sourceBitDepth != nil { state.sourceBitDepth = nil }
        if state.appName == "Music" {
            detectAppleMusicQuality()
        }
    }

    private func detectAppleMusicQuality() {
        guard let result = QualityDetector.detect() else { return }

        if state.sourceSampleRate != result.sampleRate { state.sourceSampleRate = result.sampleRate }
        if state.sourceBitDepth != result.bitDepth { state.sourceBitDepth = result.bitDepth }
        if state.sourceIsLossless != result.isLossless { state.sourceIsLossless = result.isLossless }

        if state.autoSwitchEnabled, state.transport == .wired {
            outputMonitor.forceFormat(sampleRate: result.sampleRate, bitDepth: result.bitDepth)
        }
    }

    private func detectBluetoothCodec() {
        guard let result = BluetoothCodecDetector.detect() else { return }
        if state.bluetoothCodec != result.codec { state.bluetoothCodec = result.codec }
        if state.bluetoothCodecSampleRate != result.sampleRate { state.bluetoothCodecSampleRate = result.sampleRate }
        if state.bluetoothBitrateKbps != result.bitrateKbps { state.bluetoothBitrateKbps = result.bitrateKbps }
    }

    // Every @Published write fires objectWillChange even when the new value
    // equals the old one, which was re-triggering the status bar/popover
    // render on every 2s poll tick and causing a visible resize "flicker".
    // Only write when something actually changed.
    private func refreshDevice() {
        let previousDeviceName = state.deviceName
        let newDeviceName = outputMonitor.currentDevice?.name
        let newTransport = outputMonitor.transport
        let deviceChanged = previousDeviceName != newDeviceName

        if state.deviceName != newDeviceName { state.deviceName = newDeviceName }
        if state.transport != newTransport { state.transport = newTransport }

        if let format = outputMonitor.liveFormat {
            if state.liveSampleRate != format.sampleRate { state.liveSampleRate = format.sampleRate }
            if state.liveBitDepth != format.bitDepth { state.liveBitDepth = format.bitDepth }
        }

        // Codec is renegotiated per-connection - drop the stale reading if the device changed.
        let shouldClearCodec = deviceChanged || newTransport != .bluetooth
        if shouldClearCodec, state.bluetoothCodec != nil || state.bluetoothCodecSampleRate != nil || state.bluetoothBitrateKbps != nil {
            state.bluetoothCodec = nil
            state.bluetoothCodecSampleRate = nil
            state.bluetoothBitrateKbps = nil
        }
        if deviceChanged {
            bluetoothDetectionAttempts = 0
        }
    }
}
