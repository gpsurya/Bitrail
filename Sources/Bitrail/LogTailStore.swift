import Foundation
import OSLog

// On-demand (not continuously polled) view into the raw log lines our
// detectors actually matched - lets a user see what Bitrail is "listening
// to" instead of taking its parsed output on faith. Only fetched when the
// user opens the log view, not on every poll tick, since scanning the log
// store has a real cost.
struct LogTailEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let process: String
    let message: String
}

struct LogTailStore {
    private static let predicate = NSPredicate(
        format: "(subsystem = %@) OR (process = %@) OR (process = %@)",
        "com.apple.coreaudio", "bluetoothd", "bluetoothaudiod"
    )

    static func fetchRecent(withinSeconds seconds: TimeInterval = 30 * 60, limit: Int = 20) -> [LogTailEntry] {
        guard let store = try? OSLogStore.local() else { return [] }
        let position = store.position(timeIntervalSinceEnd: -seconds)
        guard let entries = try? store.getEntries(with: [], at: position, matching: predicate) else { return [] }

        var matched = [LogTailEntry]()
        for entry in entries {
            guard let logEntry = entry as? OSLogEntryLog else { continue }
            let message = logEntry.composedMessage
            guard isRelevant(message) else { continue }
            matched.append(LogTailEntry(date: logEntry.date, process: logEntry.process, message: message))
        }
        return Array(matched.suffix(limit).reversed())
    }

    // Narrows to the exact lines our detectors key off of, so the log view
    // reads as "here's what Bitrail is using" rather than generic CoreAudio
    // chatter.
    static func isRelevant(_ message: String) -> Bool {
        message.contains("ACAppleLosslessDecoder.cpp") || message.contains("A2DP configured")
    }

    static func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
