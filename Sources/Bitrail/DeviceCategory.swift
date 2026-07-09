import Foundation

// CoreAudio's transport type only tells us wired vs. Bluetooth vs. built-in -
// it has no concept of "headphones" vs. "earbuds" vs. "speaker". We only have
// the device's user-visible name to go on, so this is a best-effort guess
// from known keywords/brands, not a real device-type API.
enum DeviceCategory: Equatable {
    case earbuds
    case overEarHeadphones
    case speaker
    case wiredDevice

    static func classify(deviceName: String?, transport: Transport) -> DeviceCategory {
        let name = (deviceName ?? "").lowercased()

        if name.contains("airpods max") {
            return .overEarHeadphones
        }
        if name.contains("airpods") || name.contains("earbud") || name.contains("earphone")
            || name.contains("buds") || name.contains("iem") {
            return .earbuds
        }

        let speakerKeywords = [
            "speaker", "homepod", "soundlink", "boombox", "boom", "megaboom",
            "soundcore", "sonos", " jbl", "harman", "ue boom", "flip", "charge"
        ]
        if speakerKeywords.contains(where: { name.contains($0) }) {
            return .speaker
        }

        if transport == .wired {
            return .wiredDevice
        }

        // Bluetooth default: most named BT audio devices that aren't
        // earbuds/speakers are over-ear headphones (Momentum, WH-1000X,
        // QuietComfort, etc.) rather than Apple's own earbud lineup.
        return .overEarHeadphones
    }

    var symbolName: String {
        switch self {
        case .earbuds: return "airpodspro"
        case .overEarHeadphones: return "headphones"
        case .speaker: return "hifispeaker.fill"
        case .wiredDevice: return "cable.connector"
        }
    }
}
