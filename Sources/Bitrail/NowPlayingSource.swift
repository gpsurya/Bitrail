import Foundation
import MediaRemoteAdapter

final class NowPlayingSource {
    private let controller = MediaController()

    // The out-of-process perl helper that bridges Apple's private
    // MediaRemote.framework can die (crash, killed, etc.) - without handling
    // onListenerTerminated, now-playing info silently goes stale forever
    // instead of recovering. Cap restarts so a persistent crash loop doesn't
    // spin forever.
    private var restartCount = 0
    private let maxRestarts = 5

    var onTrackChanged: ((appName: String?, title: String?, artist: String?)?) -> Void = { _ in }

    func start() {
        controller.onTrackInfoReceived = { [weak self] trackInfo in
            guard let self else { return }
            guard let payload = trackInfo?.payload else {
                self.onTrackChanged(nil)
                return
            }
            self.onTrackChanged((appName: payload.applicationName, title: payload.title, artist: payload.artist))
        }
        controller.onListenerTerminated = { [weak self] in
            guard let self, self.restartCount < self.maxRestarts else { return }
            self.restartCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.controller.startListening()
            }
        }
        controller.startListening()
    }

    func stop() {
        controller.stopListening()
    }
}
