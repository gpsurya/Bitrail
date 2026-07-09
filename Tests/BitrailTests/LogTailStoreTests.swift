import XCTest
@testable import Bitrail

final class LogTailStoreTests: XCTestCase {
    func testRelevantAppleMusicLine() {
        XCTAssertTrue(LogTailStore.isRelevant("... ACAppleLosslessDecoder.cpp ... Input format: ..."))
    }

    func testRelevantBluetoothLine() {
        XCTAssertTrue(LogTailStore.isRelevant("A2DP configured at 44.1 KHz. Codec: AAC-LC, VBR max: 256kbps"))
    }

    func testIrrelevantLineIsFiltered() {
        XCTAssertFalse(LogTailStore.isRelevant("some unrelated coreaudio chatter"))
    }

    func testTimestampFormatIsHHMMSS() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 9
        components.hour = 18; components.minute = 5; components.second = 42
        components.timeZone = TimeZone(identifier: "UTC")
        let date = calendar.date(from: components)!
        let formatted = LogTailStore.formattedTimestamp(date)
        // Only assert shape (HH:mm:ss), not exact value, since formatting uses local timezone.
        XCTAssertEqual(formatted.split(separator: ":").count, 3)
    }
}
