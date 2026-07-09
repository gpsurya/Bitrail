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

    var onTrackChanged: ((appName: String?, title: String?, artist: String?, bundleIdentifier: String?)?) -> Void = { _ in }

    func start() {
        controller.onTrackInfoReceived = { [weak self] trackInfo in
            guard let self else { return }
            guard let payload = trackInfo?.payload else {
                self.onTrackChanged(nil)
                return
            }
            self.onTrackChanged((
                appName: payload.applicationName,
                title: payload.title,
                artist: payload.artist,
                bundleIdentifier: payload.bundleIdentifier
            ))
        }
        controller.onListenerTerminated = { [weak self] in
            // mediaremote-adapter's termination callback threading isn't
            // documented/guaranteed to be main-thread - ActivityLog.log()
            // mutates @Published state, which must only happen on main.
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.restartCount < self.maxRestarts else {
                    ActivityLog.shared.log("Now-playing helper terminated - restart budget (\(self.maxRestarts)) exhausted, giving up")
                    return
                }
                self.restartCount += 1
                ActivityLog.shared.log("Now-playing helper (perl process) terminated - restarting (attempt \(self.restartCount)/\(self.maxRestarts))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.controller.startListening()
                }
            }
        }
        // start() is always called from AppCoordinator.start() on the main
        // thread, so this one can log directly without dispatching.
        ActivityLog.shared.log("Starting now-playing listener (mediaremote-adapter perl helper)")
        controller.startListening()
    }

    func stop() {
        controller.stopListening()
    }
}
