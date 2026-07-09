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
    @Published var bluetoothBitrateKbps: Double?

    // Output device volume, 0-1 scalar. Real metric (kAudioHardwareServiceDeviceProperty_VirtualMainVolume),
    // not a fabricated/simulated level meter - there's no real-time peak/RMS
    // API without an audio tap.
    @Published var outputVolume: Float?

    var outputVolumePercent: Int? {
        outputVolume.map { Int(($0 * 100).rounded()) }
    }

    // What's actually reaching the output device right now, in kbps.
    // Bluetooth: the negotiated codec's cap, parsed from bluetoothd's log.
    // Wired: exact PCM math (sampleRate * bitDepth * channels), not an estimate -
    // wired output is uncompressed, so this is the real transferred bitrate.
    var transferBitrateKbps: Double? {
        switch transport {
        case .bluetooth:
            return bluetoothBitrateKbps
        case .wired, .other:
            guard let sr = liveSampleRate, let bd = liveBitDepth else { return nil }
            let channels = 2.0
            return (sr * Double(bd) * channels) / 1000
        }
    }

    var deviceCategory: DeviceCategory {
        DeviceCategory.classify(deviceName: deviceName, transport: transport)
    }

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

}
