import Foundation

enum QualityTier: String {
    case lossy = "Lossy"
    case lossless = "Lossless"
    case hiRes = "Hi-Res Lossless"

    static func classify(sampleRate: Double, bitDepth: Int, sourceIsLossless: Bool) -> QualityTier {
        guard sourceIsLossless else { return .lossy }
        if sampleRate > 48_000 {
            return .hiRes
        }
        return .lossless
    }
}
