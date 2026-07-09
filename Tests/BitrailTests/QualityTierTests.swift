import XCTest
@testable import Bitrail

final class QualityTierTests: XCTestCase {
    func testLossyWhenSourceNotLossless() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 44100, bitDepth: 16, sourceIsLossless: false), .lossy)
    }

    func testLosslessAtCDQuality() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 44100, bitDepth: 16, sourceIsLossless: true), .lossless)
    }

    func testLosslessAt48kHz() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 48000, bitDepth: 24, sourceIsLossless: true), .lossless)
    }

    func testHiResAbove48kHz() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 96000, bitDepth: 24, sourceIsLossless: true), .hiRes)
    }

    func testHiResAt192kHz() {
        XCTAssertEqual(QualityTier.classify(sampleRate: 192000, bitDepth: 24, sourceIsLossless: true), .hiRes)
    }
}
