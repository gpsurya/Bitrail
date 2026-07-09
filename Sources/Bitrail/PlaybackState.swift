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

    var qualityTier: QualityTier? {
        guard appName == "Music", let sr = sourceSampleRate, let bd = sourceBitDepth else { return nil }
        return QualityTier.classify(sampleRate: sr, bitDepth: bd, sourceIsLossless: sourceIsLossless)
    }

    var statusBarText: String {
        let transportGlyph = transport == .bluetooth ? "\u{1F535}" : "\u{1F50C}"
        if let tier = qualityTier, let sr = sourceSampleRate, let bd = sourceBitDepth {
            return String(format: "%@ %@ %.1fkHz/%dbit", transportGlyph, tier.rawValue, sr / 1000, bd)
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
