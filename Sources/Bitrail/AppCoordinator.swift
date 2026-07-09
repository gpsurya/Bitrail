import Foundation

final class AppCoordinator {
    private let state = PlaybackState()
    private let nowPlaying = NowPlayingSource()
    private let outputMonitor = OutputDeviceMonitor()
    private var statusBar: StatusBarController?
    private var pollTimer: Timer?

    func start() {
        statusBar = StatusBarController(state: state)

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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshDevice()
            if self?.state.appName == "Music" {
                self?.detectAppleMusicQuality()
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

    private func refreshDevice() {
        state.deviceName = outputMonitor.currentDevice?.name
        state.transport = outputMonitor.transport
        if let format = outputMonitor.liveFormat {
            state.liveSampleRate = format.sampleRate
            state.liveBitDepth = format.bitDepth
        }
    }
}
