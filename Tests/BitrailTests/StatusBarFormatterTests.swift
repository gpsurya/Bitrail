import XCTest
@testable import Bitrail

final class StatusBarFormatterTests: XCTestCase {
    func testAppleMusicQualityLabel() {
        let state = PlaybackState()
        state.appName = KnownApp.appleMusic
        state.sourceSampleRate = 96000
        state.sourceBitDepth = 24
        let label = StatusBarFormatter.label(for: state)
        XCTAssertTrue(label.contains("96kHz/24bit"))
        XCTAssertTrue(label.contains("HiRes"))
    }

    func testMismatchWarningShown() {
        let state = PlaybackState()
        state.appName = KnownApp.appleMusic
        state.sourceSampleRate = 96000
        state.sourceBitDepth = 24
        state.liveSampleRate = 44100
        XCTAssertTrue(StatusBarFormatter.label(for: state).contains("!"))
    }

    func testBluetoothCodecLabel() {
        let state = PlaybackState()
        state.transport = .bluetooth
        state.bluetoothCodec = "AAC"
        state.bluetoothCodecSampleRate = 44100
        let label = StatusBarFormatter.label(for: state)
        XCTAssertTrue(label.contains("AAC"))
        XCTAssertTrue(label.contains("44kHz"))
    }

    func testLiveFormatFallback() {
        let state = PlaybackState()
        state.liveSampleRate = 48000
        XCTAssertTrue(StatusBarFormatter.label(for: state).contains("48kHz"))
    }

    func testDefaultLabelWhenNothingKnown() {
        let state = PlaybackState()
        XCTAssertEqual(StatusBarFormatter.label(for: state), " Bitrail")
    }
}
