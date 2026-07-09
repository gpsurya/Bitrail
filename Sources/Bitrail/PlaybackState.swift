import Foundation
import Combine

enum Transport: String {
    case wired = "Wired"
    case bluetooth = "Bluetooth"
    case other = "Other"
}

final class PlaybackState: ObservableObject {
    // Now playing (any app)
    @Published var appName: String?
    @Published var trackTitle: String?
    @Published var trackArtist: String?

    // Output device
    @Published var deviceName: String?
    @Published var transport: Transport = .other

    // Format actually leaving the Mac right now
    @Published var liveSampleRate: Double?
    @Published var liveBitDepth: Int?

    // Only populated when appName == Apple Music and log scraping succeeded
    @Published var sourceSampleRate: Double?
    @Published var sourceBitDepth: Int?
    @Published var sourceIsLossless: Bool = false

    @Published var autoSwitchEnabled: Bool = false

    // Only populated when transport == .bluetooth and log scraping succeeded.
    // Display-only: negotiated at connection time, cannot be forced.
    @Published var bluetoothCodec: String?
    @Published var bluetoothCodecSampleRate: Double?

    var qualityTier: QualityTier? {
        guard appName == "Music", let sr = sourceSampleRate, let bd = sourceBitDepth else { return nil }
        return QualityTier.classify(sampleRate: sr, bitDepth: bd, sourceIsLossless: sourceIsLossless)
    }

    // True once we have both a detected source format and a live device format
    // that disagree - i.e. auto-switch either hasn't run yet or failed.
    var hasRateMismatch: Bool {
        guard let sourceSampleRate, let liveSampleRate else { return false }
        return sourceSampleRate != liveSampleRate
    }

    var statusBarText: String {
        if transport == .bluetooth, let codec = bluetoothCodec, let rate = bluetoothCodecSampleRate {
            let name = appName ?? "No source"
            return String(format: "\u{1F535} %@ · %@ %.1fkHz", name, codec, rate / 1000)
        }

        let transportGlyph = transport == .bluetooth ? "\u{1F535}" : "\u{1F50C}"
        if let tier = qualityTier, let sr = sourceSampleRate, let bd = sourceBitDepth {
            let mismatch = hasRateMismatch ? " ⚠︎" : ""
            return String(format: "%@ %@ %.1fkHz/%dbit%@", transportGlyph, tier.rawValue, sr / 1000, bd, mismatch)
        }
        if let sr = liveSampleRate {
            let name = appName ?? "No source"
            if let bd = liveBitDepth {
                return String(format: "%@ %@ · %.1fkHz/%dbit", transportGlyph, name, sr / 1000, bd)
            }
            return String(format: "%@ %@ · %.1fkHz", transportGlyph, name, sr / 1000)
        }
        return "Bitrail"
    }
}
