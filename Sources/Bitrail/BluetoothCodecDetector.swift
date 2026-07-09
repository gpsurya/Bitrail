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
    }

    static func detect(withinSeconds seconds: TimeInterval = 15) -> Result? {
        guard let store = try? OSLogStore(scope: .system) else { return nil }
        let position = store.position(timeIntervalSinceEnd: -seconds)
        guard let entries = try? store.getEntries(at: position) else { return nil }

        for entry in entries {
            guard let logEntry = entry as? OSLogEntryLog else { continue }
            guard logEntry.process == "bluetoothd" || logEntry.process == "bluetoothaudiod" else { continue }

            let message = logEntry.composedMessage
            guard message.contains("A2DP configured"), message.contains("Codec:") else { continue }

            guard
                let rateString = substring(in: message, between: "A2DP configured at ", and: " KHz"),
                let codec = substring(in: message, between: "Codec: ", and: ",")
                    ?? substring(in: message, between: "Codec: ", and: " ")
            else { continue }

            guard let rateKHz = Double(rateString.trimmingCharacters(in: .whitespaces)) else { continue }

            let normalizedCodec = codec.trimmingCharacters(in: .whitespaces).uppercased().contains("AAC") ? "AAC" : "SBC"
            return Result(codec: normalizedCodec, sampleRate: rateKHz * 1000)
        }
        return nil
    }

    private static func substring(in text: String, between start: String, and end: String) -> String? {
        guard let startRange = text.range(of: start) else { return nil }
        guard let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else { return nil }
        return String(text[startRange.upperBound..<endRange.lowerBound])
    }
}
