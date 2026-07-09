import Foundation
import AppKit

final class AppCoordinator {
    private let state = PlaybackState()
    private let nowPlaying = NowPlayingSource()
    private let outputMonitor = OutputDeviceMonitor()
    private var statusBar: StatusBarController?
    private var pollTimer: Timer?

    // Both detectors scan the log store on every 2s poll tick, but the log
    // line each looks for only appears once (per Bluetooth connection, or per
    // Apple Music track change) - not periodically. Once it's been found, or
    // once a bounded number of attempts have failed to find it, further
    // polling is pure waste (the exact battery-drain pattern LosslessSwitcher
    // users reported). Cap retries per event instead of polling forever.
    private var bluetoothDetectionAttempts = 0
    private let maxBluetoothDetectionAttempts = 5
    private var appleMusicDetectionAttempts = 0
    private let maxAppleMusicDetectionAttempts = 5

    func stop() {
        pollTimer?.invalidate()
        nowPlaying.stop()
    }

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

        // Apple Music doesn't push format changes, so poll a bounded number of
        // times after each track change (below) rather than forever.
        // Bluetooth codec is negotiated once per connection, same idea.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshDevice()
            if self.state.appName == KnownApp.appleMusic, self.state.sourceSampleRate == nil,
               self.appleMusicDetectionAttempts < self.maxAppleMusicDetectionAttempts {
                self.appleMusicDetectionAttempts += 1
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
        appleMusicDetectionAttempts = 0
        if state.appName == KnownApp.appleMusic {
            detectAppleMusicQuality()
        }
    }

    private func detectAppleMusicQuality() {
        guard let result = QualityDetector.detect() else { return }

        if state.sourceSampleRate != result.sampleRate { state.sourceSampleRate = result.sampleRate }
        if state.sourceBitDepth != result.bitDepth { state.sourceBitDepth = result.bitDepth }

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
