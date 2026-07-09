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
        XCTAssertEqual(DeviceCategory.classify(deviceName: "JBL Flip 6", transport: .bluetooth), .speaker)
        XCTAssertEqual(DeviceCategory.classify(deviceName: "HomePod mini", transport: .bluetooth), .speaker)
    }

    func testWiredDeviceIgnoresKeywords() {
        XCTAssertEqual(DeviceCategory.classify(deviceName: "USB DAC", transport: .wired), .wiredDevice)
    }

    func testUnknownNameDefaultsToOverEar() {
        XCTAssertEqual(DeviceCategory.classify(deviceName: nil, transport: .bluetooth), .overEarHeadphones)
    }
}
