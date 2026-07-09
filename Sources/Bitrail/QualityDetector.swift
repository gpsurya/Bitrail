import Foundation
import OSLog

// Scrapes the unified log for CoreAudio's ALAC decoder lines to recover the
// sample rate / bit depth of what Apple Music is actually decoding.
// This is the same private, undocumented technique LosslessSwitcher uses -
// there is no public API that exposes this.
struct QualityDetector {
    struct Result {
        let sampleRate: Double // Hz
        let bitDepth: Int
        let isLossless: Bool
    }

    // LosslessSwitcher (the proven reference implementation) uses
    // OSLogStore.local() with an NSPredicate passed to the log daemon,
    // rather than OSLogStore(scope: .system) filtered after the fact in
    // Swift - letting the daemon do the filtering is both the precedented
    // approach and far cheaper than enumerating every system log entry.
    private static let predicate = NSPredicate(format: "subsystem = %@", "com.apple.coreaudio")

    static func detect(withinSeconds seconds: TimeInterval = 5) -> Result? {
        guard let store = try? OSLogStore.local() else { return nil }
        let position = store.position(timeIntervalSinceEnd: -seconds)
        guard let entries = try? store.getEntries(with: [], at: position, matching: predicate) else { return nil }

        for entry in entries {
            guard let logEntry = entry as? OSLogEntryLog else { continue }
            let message = logEntry.composedMessage
            guard message.contains("ACAppleLosslessDecoder.cpp"), message.contains("Input format:") else { continue }

            guard let sampleRateString = substring(in: message, between: "ch, ", and: " Hz") else { continue }
            guard let bitDepthString = substring(in: message, between: "from ", and: "-bit source") else { continue }

            let trimmedSampleRate = sampleRateString.trimmingCharacters(in: .whitespaces)
            let trimmedBitDepth = bitDepthString.trimmingCharacters(in: .whitespaces)

            guard let sampleRate = Double(trimmedSampleRate), let bitDepth = Int(trimmedBitDepth) else { continue }

            return Result(sampleRate: sampleRate, bitDepth: bitDepth, isLossless: true)
        }
        return nil
    }

    private static func substring(in text: String, between start: String, and end: String) -> String? {
        guard let startRange = text.range(of: start) else { return nil }
        guard let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else { return nil }
        return String(text[startRange.upperBound..<endRange.lowerBound])
    }
}
