import Foundation
import SwiftUI

// Only ever constructed from QualityDetector's result, which is always
// lossless (see QualityDetector.Result) - there's no lossy case because
// there's no detection path that could produce one.
enum QualityTier: String {
    case lossless = "Lossless"
    case hiRes = "Hi-Res Lossless"

    static func classify(sampleRate: Double, bitDepth: Int) -> QualityTier {
        sampleRate > 48_000 ? .hiRes : .lossless
    }

    var symbolName: String {
        switch self {
        case .lossless: return "waveform.badge.checkmark"
        case .hiRes: return "waveform.badge.plus"
        }
    }

    var tint: Color {
        switch self {
        case .lossless: return .blue
        case .hiRes: return .purple
        }
    }
}
