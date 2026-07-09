import XCTest
@testable import Bitrail

final class ActivityLogTests: XCTestCase {
    func testCapacityIsEnforced() {
        let log = ActivityLog.shared
        let startCount = log.entries.count

        for i in 0..<(ActivityLog.capacity + 50) {
            log.log("entry \(i)")
        }

        XCTAssertEqual(log.entries.count, ActivityLog.capacity)
        // Oldest entries should have been dropped, newest kept.
        XCTAssertTrue(log.entries.last?.message.hasSuffix("\(ActivityLog.capacity + 50 - 1)") ?? false)
        _ = startCount
    }
}
