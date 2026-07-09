import XCTest
@testable import Bitrail

final class QualityChainStageTests: XCTestCase {
    func testEmptyWhenNothingKnown() {
        let state = PlaybackState()
        XCTAssertTrue(state.qualityChainStages.isEmpty)
    }

    func testWiredWithAppleMusicShowsTwoStages() {
        let state = PlaybackState()
        state.appName = KnownApp.appleMusic
        state.sourceSampleRate = 96000
        state.sourceBitDepth = 24
        state.transport = .wired
        state.liveSampleRate = 96000
        state.liveBitDepth = 24
        state.deviceName = "USB DAC"

        let stages = state.qualityChainStages
        XCTAssertEqual(stages.count, 2)
        XCTAssertEqual(stages[0].title, "Hi-Res Lossless")
        XCTAssertEqual(stages[0].spec, "24-bit / 96 kHz")
        XCTAssertEqual(stages[1].title, "USB DAC")
        XCTAssertEqual(stages[1].spec, "24-bit / 96 kHz")
    }

    func testWiredWithoutAppleMusicShowsOneStage() {
        let state = PlaybackState()
        state.transport = .wired
        state.liveSampleRate = 48000
        state.liveBitDepth = 32
        state.deviceName = "MacBook Pro Speakers"

        let stages = state.qualityChainStages
        XCTAssertEqual(stages.count, 1)
        XCTAssertEqual(stages[0].title, "MacBook Pro Speakers")
        XCTAssertEqual(stages[0].spec, "32-bit / 48 kHz")
    }

    func testBluetoothWithFullChainShowsThreeStages() {
        let state = PlaybackState()
        state.appName = KnownApp.appleMusic
        state.sourceSampleRate = 44100
        state.sourceBitDepth = 16
        state.transport = .bluetooth
        state.liveSampleRate = 48000
        state.liveBitDepth = 24
        state.bluetoothCodec = "AAC"
        state.bluetoothCodecSampleRate = 44100
        state.deviceName = "MOMENTUM 4"

        let stages = state.qualityChainStages
        XCTAssertEqual(stages.count, 3)
        XCTAssertEqual(stages[0].title, "Lossless")
        XCTAssertEqual(stages[1].title, "This Mac")
        XCTAssertEqual(stages[1].spec, "24-bit / 48 kHz")
        XCTAssertEqual(stages[2].title, "MOMENTUM 4")
        XCTAssertEqual(stages[2].spec, "AAC / 44 kHz")
    }

    func testBluetoothWithoutCodecYetSkipsFinalStage() {
        let state = PlaybackState()
        state.transport = .bluetooth
        state.liveSampleRate = 48000
        state.liveBitDepth = 24

        let stages = state.qualityChainStages
        XCTAssertEqual(stages.count, 1)
        XCTAssertEqual(stages[0].title, "This Mac")
    }
}
