import XCTest
@testable import Bitrail

final class QualityTierTests: XCTestCase {
    func testLosslessAtCDQuality() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 44100, bitDepth: 16), .lossless)
    }

    func testLosslessAt48kHz() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 48000, bitDepth: 24), .lossless)
    }

    func testHiResAbove48kHz() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 96000, bitDepth: 24), .hiRes)
    }

    func testHiResAt192kHz() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 192000, bitDepth: 24), .hiRes)
    }
}
