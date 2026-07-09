import Foundation
import MediaRemoteAdapter

final class NowPlayingSource {
    private let controller = MediaController()

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
        controller.startListening()
    }
}
