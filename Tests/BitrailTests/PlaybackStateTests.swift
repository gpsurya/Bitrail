import XCTest
@testable import Bitrail

final class PlaybackStateTests: XCTestCase {
    func testNoMismatchWhenRatesMatch() {
        let state = PlaybackState()
        state.sourceSampleRate = 96000
        state.liveSampleRate = 96000
        XCTAssertFalse(state.hasRateMismatch)
    }

    func testMismatchWhenRatesDiffer() {
        let state = PlaybackState()
        state.sourceSampleRate = 96000
        state.liveSampleRate = 44100
        XCTAssertTrue(state.hasRateMismatch)
    }

    func testNoMismatchWithoutBothValues() {
        let state = PlaybackState()
        state.sourceSampleRate = 96000
        XCTAssertFalse(state.hasRateMismatch)
    }

    func testQualityTierOnlyAppliesToAppleMusic() {
        let state = PlaybackState()
        state.appName = "Spotify"
        state.sourceSampleRate = 96000
        state.sourceBitDepth = 24
        XCTAssertNil(state.qualityTier)
    }

    func testQualityTierForAppleMusic() {
        let state = PlaybackState()
        state.appName = KnownApp.appleMusic
        state.sourceSampleRate = 96000
        state.sourceBitDepth = 24
        XCTAssertEqual(state.qualityTier, .hiRes)
    }
}
