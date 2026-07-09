import Foundation
import OSLog

// Scrapes the unified log for bluetoothd's A2DP negotiation line to recover
// the codec (AAC/SBC) and sample rate a Bluetooth output device is actually
// using. Private, undocumented - there is no public API for this. Modern
// macOS only ever negotiates AAC or SBC (aptX support was dropped, LDAC was
// never supported), so this is effectively a two-way classification.
struct BluetoothCodecDetector {
    struct Result {
        let codec: String // "AAC" or "SBC"
        let sampleRate: Double // Hz
        let bitrateKbps: Double? // negotiated cap, e.g. "VBR max: 256kbps" or "Bitpool: 42 (267 kbps)"
    }

    // LosslessSwitcher (the proven reference implementation) uses
    // OSLogStore.local() with an NSPredicate passed to the log daemon rather
    // than filtering in Swift after pulling every entry - critical here
    // given our lookback window is hours wide, not seconds.
    private static let predicate = NSPredicate(format: "process = %@ OR process = %@", "bluetoothd", "bluetoothaudiod")

    // bluetoothd logs "A2DP configured" exactly once, at connection time - not
    // periodically. A short lookback window means that log line ages out and
    // is gone forever once more than `seconds` has passed since connection,
    // even though the connection (and its negotiated codec) is still active.
    // Default to a wide window so we can find the negotiation from earlier in
    // the session, not just one that happened moments ago.
    static func detect(withinSeconds seconds: TimeInterval = 6 * 60 * 60) -> Result? {
        guard let store = try? OSLogStore.local() else { return nil }
        let position = store.position(timeIntervalSinceEnd: -seconds)
        guard let entries = try? store.getEntries(with: [], at: position, matching: predicate) else { return nil }

        // Entries are chronological (oldest first) - keep the last match, since
        // that's the most recent negotiation if the device reconnected more
        // than once within the window.
        var latest: Result?

        for entry in entries {
            guard let logEntry = entry as? OSLogEntryLog else { continue }

            let message = logEntry.composedMessage
            guard message.contains("A2DP configured"), message.contains("Codec:") else { continue }

            guard
                let rateString = substring(in: message, between: "A2DP configured at ", and: " KHz"),
                let codec = substring(in: message, between: "Codec: ", and: ",")
                    ?? substring(in: message, between: "Codec: ", and: " ")
            else { continue }

            guard let rateKHz = Double(rateString.trimmingCharacters(in: .whitespaces)) else { continue }

            let normalizedCodec = codec.trimmingCharacters(in: .whitespaces).uppercased().contains("AAC") ? "AAC" : "SBC"
            latest = Result(codec: normalizedCodec, sampleRate: rateKHz * 1000, bitrateKbps: bitrateKbps(in: message))
        }
        return latest
    }

    // Handles both observed formats: "VBR max: 256kbps" (no space) and
    // "Bitpool: 42 (267 kbps)" (space before "kbps") - the space in the
    // second form meant the previous digit-scan, which stopped at the first
    // non-digit character, hit the space immediately and returned nothing
    // for every SBC connection. Skip whitespace before scanning digits.
    static func bitrateKbps(in message: String) -> Double? {
        guard let kbpsRange = message.range(of: "kbps", options: .backwards) else { return nil }
        let beforeKbps = message[..<kbpsRange.lowerBound].reversed().drop(while: { $0 == " " })
        let digits = beforeKbps.prefix(while: { $0.isNumber || $0 == "." }).reversed()
        return Double(String(digits))
    }

    private static func substring(in text: String, between start: String, and end: String) -> String? {
        guard let startRange = text.range(of: start) else { return nil }
        guard let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else { return nil }
        return String(text[startRange.upperBound..<endRange.lowerBound])
    }
}
