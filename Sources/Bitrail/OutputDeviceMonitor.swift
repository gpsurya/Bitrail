import Foundation
import Combine
import SimplyCoreAudio
import CoreAudio

final class OutputDeviceMonitor {
    private let coreAudio = SimplyCoreAudio()
    private var cancellables = Set<AnyCancellable>()

    var onChange: (() -> Void)?

    init() {
        // SimplyCoreAudio's property-change notifications can fire from a
        // background thread (rnine/SimplyCoreAudio#61) - onChange ultimately
        // mutates @Published PlaybackState properties, which must only ever
        // happen on the main thread.
        NotificationCenter.default.publisher(for: .defaultOutputDeviceChanged)
            .receive(on: DispatchQueue.main)
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

    // Real device output volume (0-1 scalar), not a signal level meter -
    // there's no CoreAudio API for actual real-time peak/RMS metering
    // without an audio tap, but this is an honest, always-available metric.
    var outputVolume: Float? {
        currentDevice?.virtualMainVolume(scope: .output)
    }

    // Wired devices only - forces the DAC's physical format to the nearest
    // match for the given source sample rate / bit depth. Bluetooth devices
    // negotiate a fixed codec/rate at connection time and cannot be forced.
    //
    // kAudioDevicePropertyNominalSampleRate/physicalFormat changes are
    // asynchronous at the CoreAudio HAL level - setting the property doesn't
    // guarantee it has taken effect by the time this call returns. We verify
    // shortly after and retry once if the device didn't actually switch,
    // rather than silently assuming success.
    func forceFormat(sampleRate: Double, bitDepth: Int, retriesLeft: Int = 1) {
        guard transport == .wired, let device = currentDevice else { return }
        guard let supportedRates = device.nominalSampleRates, !supportedRates.isEmpty else { return }

        let nearestRate = supportedRates.min(by: { abs($0 - sampleRate) < abs($1 - sampleRate) })
        guard let nearestRate else { return }

        let formats = device.streams(scope: .output)?.first?.availablePhysicalFormats?.compactMap { $0.mFormat }
        let candidate = formats?.filter { $0.mSampleRate == nearestRate }
            .min(by: { abs(Int($0.mBitsPerChannel) - bitDepth) < abs(Int($1.mBitsPerChannel) - bitDepth) })

        let alreadyCorrect: Bool
        if let candidate, let stream = device.streams(scope: .output)?.first,
           stream.physicalFormat?.mSampleRate != candidate.mSampleRate || stream.physicalFormat?.mBitsPerChannel != candidate.mBitsPerChannel {
            stream.physicalFormat = candidate
            alreadyCorrect = false
        } else if device.nominalSampleRate != nearestRate {
            device.setNominalSampleRate(nearestRate)
            alreadyCorrect = false
        } else {
            alreadyCorrect = true
        }

        guard !alreadyCorrect, retriesLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.currentDevice?.nominalSampleRate != nearestRate else { return }
            self.forceFormat(sampleRate: sampleRate, bitDepth: bitDepth, retriesLeft: retriesLeft - 1)
        }
    }
}
