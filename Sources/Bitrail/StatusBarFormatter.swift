import Foundation

// Pure text formatting for the status bar item's title, kept separate from
// StatusBarController so it's directly unit-testable without needing to
// construct any AppKit objects.
enum StatusBarFormatter {
    static func label(for state: PlaybackState) -> String {
        if let tier = state.qualityTier, let sr = state.sourceSampleRate, let bd = state.sourceBitDepth {
            let mismatch = state.hasRateMismatch ? " !" : ""
            let tierName = tier == .hiRes ? "HiRes" : tier.rawValue
            return String(format: " %.0fkHz/%dbit%@", sr / 1000, bd, mismatch) + " \(tierName)"
        }
        if state.transport == .bluetooth, let codec = state.bluetoothCodec, let rate = state.bluetoothCodecSampleRate {
            return String(format: " %@ %.0fkHz", codec, rate / 1000)
        }
        if let sr = state.liveSampleRate {
            return String(format: " %.0fkHz", sr / 1000)
        }
        return " Bitrail"
    }
}
