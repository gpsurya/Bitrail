import XCTest
@testable import Bitrail

final class BluetoothCodecDetectorTests: XCTestCase {
    func testAACFormatNoSpaceBeforeKbps() {
        let message = "A2DP configured at 44.1 KHz. Codec: AAC-LC, VBR max: 256kbps"
        XCTAssertEqual(BluetoothCodecDetector.bitrateKbps(in: message), 256)
    }

    func testSBCFormatWithSpaceBeforeKbps() {
        // Previously returned nil: the digit-scan stopped at the space
        // immediately preceding "kbps" instead of skipping it.
        let message = "A2DP configured at 44.1 KHz. Codec: SBC, Bitpool: 42 (267 kbps)"
        XCTAssertEqual(BluetoothCodecDetector.bitrateKbps(in: message), 267)
    }

    func testNoBitrateFigurePresent() {
        let message = "A2DP configured at 44.1 KHz. Codec: SBC"
        XCTAssertNil(BluetoothCodecDetector.bitrateKbps(in: message))
    }
}
