import XCTest
@testable import Bitrail

final class TransferBitrateTests: XCTestCase {
    func testWiredPCMBitrateIsExactMath() {
        let state = PlaybackState()
        state.transport = .wired
        state.liveSampleRate = 48000
        state.liveBitDepth = 24
        // 48000 * 24 * 2 channels / 1000 = 2304 kbps
        XCTAssertEqual(state.transferBitrateKbps, 2304, accuracy: 0.001)
    }

    func testBluetoothUsesNegotiatedCap() {
        let state = PlaybackState()
        state.transport = .bluetooth
        state.bluetoothBitrateKbps = 256
        state.liveSampleRate = 44100
        state.liveBitDepth = 16
        XCTAssertEqual(state.transferBitrateKbps, 256)
    }

    func testNoBitrateWithoutLiveFormat() {
        let state = PlaybackState()
        state.transport = .wired
        XCTAssertNil(state.transferBitrateKbps)
    }
}
