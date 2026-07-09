import Foundation
import Combine

// A plain, unfiltered trail of what Bitrail is actually doing internally
// (poll ticks, detection attempts and results, format-switch commands,
// track/device changes, helper restarts) - not curated or summarized. This
// is separate from LogTailStore, which reads macOS's own unified log; this
// is Bitrail's own record of its own actions, so "what Bitrail sees" is
// answerable even for things that never touch the system log at all (e.g.
// "detection attempt 3/5 found nothing").
struct ActivityLogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let message: String
}

final class ActivityLog: ObservableObject {
    static let shared = ActivityLog()

    // Ring buffer - unbounded growth over a long-running menu bar app would
    // otherwise leak memory for a debug feature nobody's looking at most of
    // the time.
    static let capacity = 300

    @Published private(set) var entries: [ActivityLogEntry] = []

    private init() {}

    func log(_ message: String) {
        entries.append(ActivityLogEntry(date: Date(), message: message))
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
    }
}
