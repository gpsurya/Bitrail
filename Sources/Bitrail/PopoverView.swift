import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var state: PlaybackState
    let onToggleAutoSwitch: () -> Void
    let onQuit: () -> Void

    @State private var showingLogs = false
    @State private var logEntries: [LogTailEntry] = []
    @State private var isLoadingLogs = false

    var body: some View {
        ZStack {
            mainStack
                .opacity(showingLogs ? 0 : 1)
                .rotation3DEffect(.degrees(showingLogs ? -90 : 0), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(!showingLogs)

            logStack
                .opacity(showingLogs ? 1 : 0)
                .rotation3DEffect(.degrees(showingLogs ? 0 : 90), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(showingLogs)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showingLogs)
        .padding(12)
        .frame(width: 300)
        // No opaque background here on purpose - NSPopover already draws its
        // own rounded/vibrant chrome. A full-bleed rectangular background
        // behind that clashes with the popover's rounded corners and shows
        // up as a visible seam/shade at the top and bottom edges.
    }

    private var mainStack: some View {
        VStack(spacing: 10) {
            qualityHeader
            nowPlayingCard
            transferCard
            deviceCard
            footer
        }
    }

    // MARK: Header

    private var qualityHeader: some View {
        GlassCard(accent: state.qualityTier?.tint ?? Theme.Accent.quality) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Quality", symbol: "waveform", accent: state.qualityTier?.tint ?? Theme.Accent.quality)

                if let tier = state.qualityTier, let sr = state.sourceSampleRate, let bd = state.sourceBitDepth {
                    HStack(spacing: 10) {
                        Image(systemName: tier.symbolName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(tier.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.rawValue)
                                .font(Theme.mono(15, weight: .bold))
                            Text(String(format: "%.1f kHz / %d bit", sr / 1000, bd))
                                .font(Theme.mono(12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else if state.transport == .bluetooth, let codec = state.bluetoothCodec, let rate = state.bluetoothCodecSampleRate {
                    HStack(spacing: 10) {
                        Image(systemName: state.deviceCategory.symbolName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(codec)
                                .font(Theme.mono(15, weight: .bold))
                            Text(String(format: "%.1f kHz (Bluetooth)", rate / 1000))
                                .font(Theme.mono(12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else if let sr = state.liveSampleRate {
                    HStack(spacing: 10) {
                        Image(systemName: "hifispeaker")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Device output")
                                .font(Theme.mono(15, weight: .bold))
                            Text(String(format: bitDepthFormat(state.liveBitDepth), sr / 1000, state.liveBitDepth ?? 0))
                                .font(Theme.mono(12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    Text("No audio detected")
                        .font(Theme.mono(13))
                        .foregroundStyle(.secondary)
                }

                if state.hasRateMismatch {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 10))
                        Text("Device is at \(formattedRate(state.liveSampleRate)), source is \(formattedRate(state.sourceSampleRate))")
                            .font(Theme.mono(10))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func bitDepthFormat(_ bitDepth: Int?) -> String {
        bitDepth != nil ? "%.1f kHz / %d bit" : "%.1f kHz"
    }

    private func formattedRate(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return String(format: "%.1fkHz", rate / 1000)
    }

    // MARK: Now Playing

    private var nowPlayingCard: some View {
        GlassCard(accent: Theme.Accent.nowPlaying) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "Now Playing", symbol: "music.note", accent: Theme.Accent.nowPlaying)
                if let app = state.appName {
                    Text(app)
                        .font(.system(size: 13, weight: .semibold))
                    if let title = state.trackTitle {
                        Text([title, state.trackArtist].compactMap { $0 }.joined(separator: " — "))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("Nothing playing")
                        .font(Theme.mono(13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Transfer

    private var transferCard: some View {
        GlassCard(accent: Theme.Accent.transfer) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Transfer", symbol: "arrow.up.arrow.down", accent: Theme.Accent.transfer)

                if state.transport == .bluetooth {
                    if let bitrate = state.transferBitrateKbps {
                        HStack(spacing: 10) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Theme.Accent.transfer)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "~%.0f kbps", bitrate))
                                    .font(Theme.mono(15, weight: .bold))
                                Text("Negotiated Bluetooth link cap")
                                    .font(Theme.mono(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    } else {
                        Text("Waiting for codec negotiation…")
                            .font(Theme.mono(12))
                            .foregroundStyle(.secondary)
                    }
                } else if let bitrate = state.transferBitrateKbps {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.Accent.transfer)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.0f kbps", bitrate))
                                .font(Theme.mono(15, weight: .bold))
                            Text("Uncompressed PCM (exact, not estimated)")
                                .font(Theme.mono(11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    Text("No output stream detected")
                        .font(Theme.mono(12))
                        .foregroundStyle(.secondary)
                }

                Text("Source app's own encoding bitrate (e.g. Spotify's) isn't exposed by any public API - this is what's actually leaving the Mac.")
                    .font(Theme.mono(10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Device

    private var deviceCard: some View {
        GlassCard(accent: Theme.Accent.device) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Output Device", symbol: "speaker.wave.2", accent: Theme.Accent.device)

                HStack(spacing: 8) {
                    Image(systemName: state.deviceCategory.symbolName)
                        .foregroundStyle(Theme.Accent.device)
                    Text(state.deviceName ?? "Unknown")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(state.transport.rawValue)
                        .font(Theme.mono(10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Accent.device.opacity(0.15), in: Capsule())
                }

                if state.transport == .wired {
                    Toggle("Auto-match sample rate", isOn: Binding(
                        get: { state.autoSwitchEnabled },
                        set: { _ in onToggleAutoSwitch() }
                    ))
                    .font(Theme.mono(12))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                if state.transport == .bluetooth {
                    Text("Bluetooth codec/rate is fixed at connection time and can't be forced.")
                        .font(Theme.mono(10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Live Tail (log viewer)

    private var logStack: some View {
        VStack(spacing: 10) {
            GlassCard(accent: Theme.Accent.logs) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionLabel(title: "Live Tail", symbol: "terminal", accent: Theme.Accent.logs)
                        Spacer()
                        if isLoadingLogs {
                            ProgressView().controlSize(.small)
                        } else {
                            Button(action: loadLogs) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.Accent.logs)
                        }
                    }

                    Text("Raw log lines Bitrail's detectors matched - what it's actually listening to.")
                        .font(Theme.mono(10))
                        .foregroundStyle(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if logEntries.isEmpty && !isLoadingLogs {
                                Text("No matching log lines in the last 30 minutes.")
                                    .font(Theme.mono(11))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(logEntries) { entry in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(LogTailStore.formattedTimestamp(entry.date))  \(entry.process)")
                                        .font(Theme.mono(9, weight: .semibold))
                                        .foregroundStyle(Theme.Accent.logs)
                                    Text(entry.message)
                                        .font(Theme.mono(9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                }
            }
            footer
        }
        .onAppear { if logEntries.isEmpty { loadLogs() } }
    }

    private func loadLogs() {
        isLoadingLogs = true
        DispatchQueue.global(qos: .userInitiated).async {
            let entries = LogTailStore.fetchRecent()
            DispatchQueue.main.async {
                logEntries = entries
                isLoadingLogs = false
            }
        }
    }

    // MARK: Footer

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var repoURL: URL {
        URL(string: "https://github.com/gpsurya/Bitrail/releases/tag/v\(appVersion)")!
    }

    private var footer: some View {
        HStack {
            Link(destination: repoURL) {
                Text("Bitrail v\(appVersion)")
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: {
                withAnimation { showingLogs.toggle() }
                if showingLogs { loadLogs() }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: showingLogs ? "arrow.uturn.backward" : "terminal")
                    Text(showingLogs ? "Back" : "Live Tail")
                }
                .font(Theme.mono(10, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Accent.logs)

            Spacer()

            Button("Quit", action: onQuit)
                .font(Theme.mono(11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }
}
