import SwiftUI
import AudioToolbox
import Accelerate
import Combine

// Real FFT-driven levels from the Mac's actual output audio (via
// SystemAudioTap), not a canned/looping animation. Only runs while something
// is actually playing, since engaging the tap triggers macOS's system audio
// capture permission prompt and has a real (if small) CPU cost.
@available(macOS 14.2, *)
final class AudioLevelMonitor: ObservableObject {
    static let bandCount = 9

    @Published private(set) var bands: [Float] = Array(repeating: 0, count: AudioLevelMonitor.bandCount)
    @Published private(set) var isAvailable = true // false only after activation actually fails (e.g. permission denied)

    private let tap = SystemAudioTap()
    private let queue = DispatchQueue(label: "com.bitrail.audiolevel", qos: .userInitiated)

    // Fixed-size FFT window - IOProc delivers variable frame counts per
    // callback depending on the device, so samples are accumulated into a
    // ring buffer and processed in fixed 512-sample chunks.
    private static let fftSize = 512
    private static let log2n = vDSP_Length(log2(Double(fftSize)))
    private var sampleBuffer: [Float] = []
    private let fftSetup: FFTSetup?
    private var running = false

    init() {
        fftSetup = vDSP_create_fftsetup(Self.log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let fftSetup { vDSP_destroy_fftsetup(fftSetup) }
        stop()
    }

    private var loggedFirstCallback = false
    private var lastDiagnosticLog = Date.distantPast

    func start() {
        guard !running else { return }
        running = true
        loggedFirstCallback = false
        ActivityLog.shared.log("Visualizer: activating system audio tap")

        tap.activate()
        guard tap.activated, let format = tap.tapStreamDescription else {
            ActivityLog.shared.log("Visualizer: tap activation failed - \(tap.errorMessage ?? "unknown error")")
            DispatchQueue.main.async { [weak self] in self?.isAvailable = false }
            running = false
            return
        }
        ActivityLog.shared.log("Visualizer: tap activated, format \(format.mChannelsPerFrame)ch / \(Int(format.mSampleRate))Hz")

        let channelCount = Int(format.mChannelsPerFrame)
        guard channelCount > 0 else {
            ActivityLog.shared.log("Visualizer: tap format reports 0 channels - aborting")
            DispatchQueue.main.async { [weak self] in self?.isAvailable = false }
            running = false
            return
        }

        do {
            try tap.run(on: queue) { [weak self] _, inputData, _, _, _ in
                self?.process(inputData, channelCount: channelCount)
            }
            ActivityLog.shared.log("Visualizer: IOProc started, waiting for audio callbacks")
        } catch {
            ActivityLog.shared.log("Visualizer: tap.run() failed - \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in self?.isAvailable = false }
            running = false
        }
    }

    func stop() {
        guard running else { return }
        running = false
        tap.invalidate()
        // sampleBuffer is mutated by process() on `queue` (a background audio
        // callback queue) - clearing it here on the main thread without
        // synchronization would be a data race if a callback were still
        // in-flight. Dispatching the clear onto the same serial queue
        // orders it after any pending/in-progress callback.
        queue.async { [weak self] in self?.sampleBuffer.removeAll() }
        bandCeilingDb = Array(repeating: -60, count: Self.bandCount)
        bands = Array(repeating: 0, count: Self.bandCount)
        ActivityLog.shared.log("Visualizer: tap stopped")
    }

    private func process(_ bufferList: UnsafePointer<AudioBufferList>, channelCount: Int) {
        // Guards against acting on a stray callback that arrives just after
        // stop() - not a full lock, but avoids resurrecting bands/logging
        // after we've already reset everything to zero.
        guard running else { return }

        if !loggedFirstCallback {
            loggedFirstCallback = true
            DispatchQueue.main.async { ActivityLog.shared.log("Visualizer: first audio callback received") }
        }

        let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
        guard let first = abl.first, let dataPointer = first.mData else {
            DispatchQueue.main.async { ActivityLog.shared.log("Visualizer: callback had no audio data buffer") }
            return
        }

        let frameCount = Int(first.mDataByteSize) / MemoryLayout<Float>.size / max(channelCount, 1)
        guard frameCount > 0 else { return }

        let samples = dataPointer.assumingMemoryBound(to: Float.self)

        // Downmix to mono by averaging channels (data is interleaved).
        var mono = [Float](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            var sum: Float = 0
            for channel in 0..<channelCount {
                sum += samples[frame * channelCount + channel]
            }
            mono[frame] = sum / Float(channelCount)
        }

        sampleBuffer.append(contentsOf: mono)

        // Throttled peak-amplitude diagnostic - if this stays at 0, the tap
        // itself isn't receiving real audio (permission/routing issue), not
        // a scaling problem in the FFT/dB mapping below.
        if Date().timeIntervalSince(lastDiagnosticLog) > 2 {
            lastDiagnosticLog = Date()
            var peak: Float = 0
            vDSP_maxmgv(mono, 1, &peak, vDSP_Length(mono.count))
            DispatchQueue.main.async { ActivityLog.shared.log(String(format: "Visualizer: peak sample amplitude %.5f", peak)) }
        }

        while sampleBuffer.count >= Self.fftSize {
            let chunk = Array(sampleBuffer.prefix(Self.fftSize))
            sampleBuffer.removeFirst(Self.fftSize)
            let rawDb = Self.computeBandDb(chunk, fftSetup: fftSetup)
            DispatchQueue.main.async { [weak self] in
                self?.normalizeSmoothAndPublish(rawDb)
            }
        }
    }

    // Bass carries far more raw energy than treble in almost all music, so a
    // single fixed dB range either clips bass at max constantly or leaves
    // treble reading near zero. Each band instead tracks its own recent
    // ceiling (rising instantly to a new peak, decaying slowly otherwise)
    // and normalizes against a fixed dynamic-range window below that -
    // standard per-band AGC, so quiet and loud bands both use their full
    // visual range relative to their own history.
    private var bandCeilingDb: [Float] = Array(repeating: -60, count: AudioLevelMonitor.bandCount)
    private static let dynamicRangeDb: Float = 42
    // FFT frames arrive roughly every ~11ms (512 samples @ 48kHz) - a slow
    // decay here means the ceiling never actually drops between musical
    // peaks, keeping everything pinned near the top of the range.
    private static let ceilingDecayPerFrame: Float = 1.2
    // Purely relative "how close to its own recent ceiling" normalization
    // has a real flaw: a near-constant signal (silence, or a paused/idle
    // output) reads as "at its own ceiling" = maxed out, regardless of
    // whether that ceiling is loud or near-silent. An absolute floor gate
    // fixes this - if a band's ceiling has never risen above this in
    // absolute terms, there's no real signal there, full stop.
    private static let absoluteSilenceFloorDb: Float = -55

    private func normalizeSmoothAndPublish(_ rawDb: [Float]) {
        guard rawDb.count == bands.count, rawDb.count == bandCeilingDb.count else { return }

        var updated = bands
        for i in 0..<updated.count {
            let db = rawDb[i]
            bandCeilingDb[i] = max(db, bandCeilingDb[i] - Self.ceilingDecayPerFrame)

            let target: Float
            if bandCeilingDb[i] < Self.absoluteSilenceFloorDb {
                target = 0
            } else {
                let floor = bandCeilingDb[i] - Self.dynamicRangeDb
                target = min(1, max(0, (db - floor) / Self.dynamicRangeDb))
            }
            // Fast attack, slower decay - reads as responsive but not jittery.
            updated[i] = target > updated[i] ? target : updated[i] * 0.7 + target * 0.3
        }
        bands = updated
    }

    private static func computeBandDb(_ samples: [Float], fftSetup: FFTSetup?) -> [Float] {
        guard let fftSetup else { return Array(repeating: 0, count: bandCount) }

        var windowed = samples
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // vDSP_ctoz via withMemoryRebound(to: DSPComplex.self) is a documented
        // trap - it compiles fine but silently produces garbage (confirmed by
        // jscalo/tempi-fft's own source comments: "results in garbage values
        // being stored to the complexBuffer's real and imag parts"). Manually
        // deinterleaving even/odd samples into realp/imagp is their proven
        // working alternative, and what's used here instead.
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<(fftSize / 2) {
            realp[i] = windowed[i * 2]
            imagp[i] = windowed[i * 2 + 1]
        }

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Group into log-spaced bands (bass through treble) rather than
        // linear bins, so low-frequency energy (which dominates most music)
        // doesn't just fill the first band and leave the rest empty.
        var bandValues = [Float](repeating: 0, count: bandCount)
        let usableBins = magnitudes.count
        let minBin = 1
        let maxBin = usableBins - 1
        for i in 0..<bandCount {
            let startFraction = pow(Double(maxBin) / Double(minBin), Double(i) / Double(bandCount))
            let endFraction = pow(Double(maxBin) / Double(minBin), Double(i + 1) / Double(bandCount))
            let start = max(minBin, Int(Double(minBin) * startFraction))
            let end = min(maxBin, max(start + 1, Int(Double(minBin) * endFraction)))
            var sum: Float = 0
            for bin in start..<end { sum += magnitudes[bin] }
            let avg = sum / Float(max(1, end - start))
            // Raw dB (10*log10 of power) - normalization against each band's
            // own recent history happens in normalizeSmoothAndPublish, not here.
            bandValues[i] = 10 * log10f(max(avg, 1e-10))
        }
        return bandValues
    }
}

struct AudioVisualizerView: View {
    @ObservedObject var state: PlaybackState
    @ObservedObject var visibility: PopoverVisibility

    var body: some View {
        if #available(macOS 14.2, *) {
            AudioVisualizerContent(state: state, visibility: visibility)
        } else {
            EmptyView()
        }
    }
}

@available(macOS 14.2, *)
private struct AudioVisualizerContent: View {
    @ObservedObject var state: PlaybackState
    @ObservedObject var visibility: PopoverVisibility
    @StateObject private var monitor = AudioLevelMonitor()

    var body: some View {
        Group {
            if monitor.isAvailable {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<monitor.bands.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(LinearGradient(
                                colors: [Theme.Accent.nowPlaying, Theme.Accent.quality],
                                startPoint: .bottom, endPoint: .top
                            ))
                            .frame(height: 4 + CGFloat(monitor.bands[i]) * 28)
                    }
                }
                .frame(height: 32, alignment: .bottom)
                .animation(.linear(duration: 0.05), value: monitor.bands)
            }
        }
        // Only actually engage the system audio tap while the popover is
        // genuinely visible on screen - see PopoverVisibility's doc comment
        // for why onAppear/onDisappear alone can't be trusted for this.
        .onChange(of: visibility.isVisible) { nowVisible in
            if nowVisible { monitor.start() } else { monitor.stop() }
        }
        .onAppear { if visibility.isVisible { monitor.start() } }
        .onDisappear { monitor.stop() }
    }
}
