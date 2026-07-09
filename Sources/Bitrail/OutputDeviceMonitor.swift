import Foundation
import Combine
import SimplyCoreAudio
import CoreAudio

final class OutputDeviceMonitor {
    private let coreAudio = SimplyCoreAudio()
    private var cancellables = Set<AnyCancellable>()

    var onChange: (() -> Void)?

    init() {
        NotificationCenter.default.publisher(for: .defaultOutputDeviceChanged)
            .sink { [weak self] _ in self?.onChange?() }
            .store(in: &cancellables)
    }

    var currentDevice: AudioDevice? {
        coreAudio.defaultOutputDevice
    }

    var transport: Transport {
        guard let device = currentDevice else { return .other }
        switch device.transportType {
        case .bluetooth, .bluetoothLE:
            return .bluetooth
        case .usb, .aggregate, .virtual, .builtIn, .displayPort, .thunderbolt, .fireWire, .pci, .hdmi:
            return .wired
        default:
            return .other
        }
    }

    var liveFormat: (sampleRate: Double, bitDepth: Int?)? {
        guard let device = currentDevice, let rate = device.nominalSampleRate else { return nil }
        let bitDepth = device.streams(scope: .output)?.first?.physicalFormat?.mBitsPerChannel
        return (rate, bitDepth.map(Int.init))
    }

    // Wired devices only - forces the DAC's physical format to the nearest
    // match for the given source sample rate / bit depth. Bluetooth devices
    // negotiate a fixed codec/rate at connection time and cannot be forced.
    func forceFormat(sampleRate: Double, bitDepth: Int) {
        guard transport == .wired, let device = currentDevice else { return }
        guard let supportedRates = device.nominalSampleRates, !supportedRates.isEmpty else { return }

        let nearestRate = supportedRates.min(by: { abs($0 - sampleRate) < abs($1 - sampleRate) })
        guard let nearestRate else { return }

        let formats = device.streams(scope: .output)?.first?.availablePhysicalFormats?.compactMap { $0.mFormat }
        let candidate = formats?.filter { $0.mSampleRate == nearestRate }
            .min(by: { abs(Int($0.mBitsPerChannel) - bitDepth) < abs(Int($1.mBitsPerChannel) - bitDepth) })

        if let candidate, let stream = device.streams(scope: .output)?.first,
           stream.physicalFormat?.mSampleRate != candidate.mSampleRate || stream.physicalFormat?.mBitsPerChannel != candidate.mBitsPerChannel {
            stream.physicalFormat = candidate
        } else if device.nominalSampleRate != nearestRate {
            device.setNominalSampleRate(nearestRate)
        }
    }
}
