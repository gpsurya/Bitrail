import XCTest
@testable import Bitrail

final class OutputVolumeTests: XCTestCase {
    func testVolumePercentRoundsCorrectly() {
        let state = PlaybackState()
        state.outputVolume = 0.746
        XCTAssertEqual(state.outputVolumePercent, 75)
    }

    func testZeroVolume() {
        let state = PlaybackState()
        state.outputVolume = 0
        XCTAssertEqual(state.outputVolumePercent, 0)
    }

    func testFullVolume() {
        let state = PlaybackState()
        state.outputVolume = 1
        XCTAssertEqual(state.outputVolumePercent, 100)
    }

    func testNilVolumeWhenUnavailable() {
        let state = PlaybackState()
        XCTAssertNil(state.outputVolumePercent)
    }
}
