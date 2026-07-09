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

    func testBluetoothStatusTextShowsCodec() {
        let state = PlaybackState()
        state.transport = .bluetooth
        state.appName = "Music"
        state.bluetoothCodec = "AAC"
        state.bluetoothCodecSampleRate = 48000
        XCTAssertTrue(state.statusBarText.contains("AAC"))
        XCTAssertTrue(state.statusBarText.contains("48.0kHz"))
    }
}
