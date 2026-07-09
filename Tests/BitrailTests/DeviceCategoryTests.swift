import XCTest
@testable import Bitrail

final class DeviceCategoryTests: XCTestCase {
    func testOverEarHeadphonesLikeMomentum4() {
        XCTAssertEqual(DeviceCategory.classify(deviceName: "MOMENTUM 4", transport: .bluetooth), .overEarHeadphones)
    }

    func testSonyOverEarHeadphones() {
        XCTAssertEqual(DeviceCategory.classify(deviceName: "WH-1000XM5", transport: .bluetooth), .overEarHeadphones)
    }

    func testAirPodsProAreEarbuds() {
        XCTAssertEqual(DeviceCategory.classify(deviceName: "AirPods Pro", transport: .bluetooth), .earbuds)
    }

    func testAirPodsMaxAreOverEar() {
        XCTAssertEqual(DeviceCategory.classify(deviceName: "AirPods Max", transport: .bluetooth), .overEarHeadphones)
    }

    func testBluetoothSpeaker() {
        // Regression: "jbl" was previously listed as " jbl" (leading space),
        // which never matches when JBL is the first word of the device name -
        // exactly this case. Only matched by accident before, via "flip".
        XCTAssertEqual(DeviceCategory.classify(deviceName: "JBL Flip 6", transport: .bluetooth), .speaker)
        XCTAssertEqual(DeviceCategory.classify(deviceName: "HomePod mini", transport: .bluetooth), .speaker)
        XCTAssertEqual(DeviceCategory.classify(deviceName: "My JBL Charge", transport: .bluetooth), .speaker)
    }

    func testGenericWordsAloneDontFalsePositiveAsSpeaker() {
        // "flip" and "charge" alone (without "jbl") shouldn't misclassify an
        // unrelated device that happens to contain those common words.
        XCTAssertEqual(DeviceCategory.classify(deviceName: "My Charge 5 Watch Audio", transport: .bluetooth), .overEarHeadphones)
    }

    func testWiredDeviceIgnoresKeywords() {
        XCTAssertEqual(DeviceCategory.classify(deviceName: "USB DAC", transport: .wired), .wiredDevice)
    }

    func testUnknownNameDefaultsToOverEar() {
        XCTAssertEqual(DeviceCategory.classify(deviceName: nil, transport: .bluetooth), .overEarHeadphones)
    }
}
