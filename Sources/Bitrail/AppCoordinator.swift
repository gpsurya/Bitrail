import Foundation
import AppKit

final class AppCoordinator {
    private let state = PlaybackState()
    private let nowPlaying = NowPlayingSource()
    private let outputMonitor = OutputDeviceMonitor()
    private var statusBar: StatusBarController?
    private var pollTimer: Timer?

    func start() {
        let bar = StatusBarController(state: state)
        bar.onToggleAutoSwitch = { [weak self] in self?.state.autoSwitchEnabled.toggle() }
        bar.onQuit = { NSApp.terminate(nil) }
        statusBar = bar

        outputMonitor.onChange = { [weak self] in self?.refreshDevice() }
        refreshDevice()

        nowPlaying.onTrackChanged = { [weak self] info in
            guard let self else { return }
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
            if self.state.transport == .bluetooth, self.state.bluetoothCodec == nil {
                self.detectBluetoothCodec()
            }
        }
    }

    private func handleTrackChange() {
        state.sourceSampleRate = nil
        state.sourceBitDepth = nil
        if state.appName == "Music" {
            detectAppleMusicQuality()
        }
    }

    private func detectAppleMusicQuality() {
        guard let result = QualityDetector.detect() else { return }
        state.sourceSampleRate = result.sampleRate
        state.sourceBitDepth = result.bitDepth
        state.sourceIsLossless = result.isLossless

        if state.autoSwitchEnabled, state.transport == .wired {
            outputMonitor.forceFormat(sampleRate: result.sampleRate, bitDepth: result.bitDepth)
        }
    }

    private func detectBluetoothCodec() {
        guard let result = BluetoothCodecDetector.detect() else { return }
        state.bluetoothCodec = result.codec
        state.bluetoothCodecSampleRate = result.sampleRate
    }

    private func refreshDevice() {
        let previousDeviceName = state.deviceName
        state.deviceName = outputMonitor.currentDevice?.name
        state.transport = outputMonitor.transport
        if let format = outputMonitor.liveFormat {
            state.liveSampleRate = format.sampleRate
            state.liveBitDepth = format.bitDepth
        }

        // Codec is renegotiated per-connection - drop the stale reading if the device changed.
        if state.deviceName != previousDeviceName || state.transport != .bluetooth {
            state.bluetoothCodec = nil
            state.bluetoothCodecSampleRate = nil
        }
    }
}
