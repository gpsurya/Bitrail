import Foundation

// A single stop in the audio path, e.g. "Track (source) -> This Mac -> Headphones".
// Modeled after Amazon Music's "Track Quality / Device / Output" chain -
// each stage shows only the format it actually handles, no derived bitrate.
struct QualityChainStage: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let spec: String
}

extension PlaybackState {
    // Builds the chain from whatever's actually known right now:
    // - Track: only when Apple Music's source format was detected.
    // - This Mac: only relevant for Bluetooth, where the Mac-side format can
    //   differ from what's actually negotiated over the air to the headphones.
    //   For wired, there's no separate negotiation step, so this stage would
    //   just repeat the final Output stage - skipped to avoid a fake duplicate.
    // - Output: the physical device - Bluetooth's negotiated codec/rate if
    //   known, otherwise the Mac's live format (which for wired *is* the
    //   final output).
    var qualityChainStages: [QualityChainStage] {
        var stages = [QualityChainStage]()

        if let tier = qualityTier, let sr = sourceSampleRate, let bd = sourceBitDepth {
            stages.append(QualityChainStage(
                icon: tier.symbolName,
                title: tier.rawValue,
                spec: String(format: "%d-bit / %.0f kHz", bd, sr / 1000)
            ))
        }

        if transport == .bluetooth, let liveSr = liveSampleRate {
            stages.append(QualityChainStage(
                icon: "laptopcomputer",
                title: "This Mac",
                spec: liveBitDepth.map { String(format: "%d-bit / %.0f kHz", $0, liveSr / 1000) }
                    ?? String(format: "%.0f kHz", liveSr / 1000)
            ))
        }

        if transport == .bluetooth, let codec = bluetoothCodec, let btSr = bluetoothCodecSampleRate {
            stages.append(QualityChainStage(
                icon: deviceCategory.symbolName,
                title: deviceName ?? "Bluetooth Output",
                spec: String(format: "%@ / %.0f kHz", codec, btSr / 1000)
            ))
        } else if transport != .bluetooth, let liveSr = liveSampleRate {
            stages.append(QualityChainStage(
                icon: deviceCategory.symbolName,
                title: deviceName ?? "Output",
                spec: liveBitDepth.map { String(format: "%d-bit / %.0f kHz", $0, liveSr / 1000) }
                    ?? String(format: "%.0f kHz", liveSr / 1000)
            ))
        }

        return stages
    }
}
