import Foundation
import AudioToolbox
import OSLog

// Adapted from Apple's own reference sample (insidegui/AudioCap,
// github.com/insidegui/AudioCap) for the Core Audio Process Tap API
// introduced in macOS 14.2 (AudioHardwareCreateProcessTap/CATapDescription).
// Unlike that sample (which taps ONE selected process), this taps the whole
// system output - we want to visualize whatever's actually playing, not ask
// the user to pick a process.
//
// This is real audio capture, not a simulated/decorative animation - macOS
// will show its own system permission prompt the first time a tap is
// engaged, same category as microphone/screen-recording permissions.
@available(macOS 14.2, *)
final class SystemAudioTap {
    private let logger = Logger(subsystem: "com.bitrail.app", category: "SystemAudioTap")

    private var processTapID: AudioObjectID = .unknown
    private var aggregateDeviceID: AudioObjectID = .unknown
    private var deviceProcID: AudioDeviceIOProcID?
    private(set) var tapStreamDescription: AudioStreamBasicDescription?
    private(set) var errorMessage: String?

    private(set) var activated = false

    func activate() {
        guard !activated else { return }
        activated = true
        errorMessage = nil

        do {
            try prepare()
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            activated = false
        }
    }

    func invalidate() {
        guard activated else { return }
        defer { activated = false }

        if aggregateDeviceID.isValid {
            _ = AudioDeviceStop(aggregateDeviceID, deviceProcID)
            if let deviceProcID {
                _ = AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
                self.deviceProcID = nil
            }
            _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = .unknown
        }

        if processTapID.isValid {
            _ = AudioHardwareDestroyProcessTap(processTapID)
            processTapID = .unknown
        }
    }

    private func prepare() throws {
        let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = .unmuted

        var tapID: AudioObjectID = .unknown
        var err = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        guard err == noErr else { throw "Process tap creation failed with error \(err)" }
        processTapID = tapID

        let systemOutputID = try AudioObjectID.system.readDefaultSystemOutputDevice()
        let outputUID = try systemOutputID.readDeviceUID()
        let aggregateUID = UUID().uuidString

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Bitrail-Visualizer-Tap",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: tapDescription.uuid.uuidString
            ]]
        ]

        tapStreamDescription = try tapID.readAudioTapStreamBasicDescription()

        var newAggregateID: AudioObjectID = .unknown
        err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &newAggregateID)
        guard err == noErr else { throw "Failed to create aggregate device: \(err)" }
        aggregateDeviceID = newAggregateID
    }

    func run(on queue: DispatchQueue, ioBlock: @escaping AudioDeviceIOBlock) throws {
        guard activated else { throw "run() called before activate()" }

        var procID: AudioDeviceIOProcID?
        var err = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateDeviceID, queue, ioBlock)
        guard err == noErr else { throw "Failed to create device I/O proc: \(err)" }
        deviceProcID = procID

        err = AudioDeviceStart(aggregateDeviceID, procID)
        guard err == noErr else { throw "Failed to start audio device: \(err)" }
    }

    deinit { invalidate() }
}

// MARK: - Minimal Core Audio property helpers (subset of insidegui/AudioCap's CoreAudioUtils.swift)

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    static let unknown = kAudioObjectUnknown
    var isValid: Bool { self != .unknown }

    func readDefaultSystemOutputDevice() throws -> AudioDeviceID {
        try read(kAudioHardwarePropertyDefaultSystemOutputDevice, defaultValue: AudioDeviceID.unknown)
    }

    func readDeviceUID() throws -> String {
        try readString(kAudioDevicePropertyDeviceUID)
    }

    func readAudioTapStreamBasicDescription() throws -> AudioStreamBasicDescription {
        try read(kAudioTapPropertyFormat, defaultValue: AudioStreamBasicDescription())
    }

    private func readString(_ selector: AudioObjectPropertySelector) throws -> String {
        try read(selector, defaultValue: "" as CFString) as String
    }

    private func read<T>(_ selector: AudioObjectPropertySelector, defaultValue: T) throws -> T {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var err = AudioObjectGetPropertyDataSize(self, &address, 0, nil, &dataSize)
        guard err == noErr else { throw "Error reading data size: \(err)" }

        var value: T = defaultValue
        err = withUnsafeMutablePointer(to: &value) { ptr in
            AudioObjectGetPropertyData(self, &address, 0, nil, &dataSize, ptr)
        }
        guard err == noErr else { throw "Error reading data: \(err)" }
        return value
    }
}

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
}
