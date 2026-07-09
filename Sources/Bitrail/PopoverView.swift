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
            deviceCard
            footer
        }
    }

    // MARK: Quality (source app's format + what's actually reaching the output, merged into one card)

    private var qualityHeader: some View {
        GlassCard(accent: state.qualityTier?.tint ?? Theme.Accent.quality) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Quality", symbol: "waveform", accent: state.qualityTier?.tint ?? Theme.Accent.quality)

                let stages = state.qualityChainStages
                if stages.isEmpty {
                    Text("No audio detected")
                        .font(Theme.mono(13))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                            qualityChainRow(stage, isLast: index == stages.count - 1)
                        }
                    }
                }

                if state.transport == .bluetooth, state.bluetoothCodec == nil {
                    Text("Waiting for codec negotiation…")
                        .font(Theme.mono(10))
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

    // One stop in the Track -> This Mac -> Output chain, connected by a
    // vertical line - same visual metaphor as Amazon Music's audio quality
    // panel, built only from data we actually have (no fabricated stage).
    private func qualityChainRow(_ stage: QualityChainStage, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Image(systemName: stage.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Accent.quality)
                    .frame(width: 22, height: 22)
                    .background(Theme.Accent.quality.opacity(0.15), in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Theme.Accent.quality.opacity(0.25))
                        .frame(width: 1.5)
                        .frame(minHeight: 14)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(stage.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(stage.spec)
                    .font(Theme.mono(11))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, isLast ? 0 : 10)
            Spacer()
        }
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
                    HStack {
                        Text("Auto-match sample rate")
                            .font(Theme.mono(12))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { state.autoSwitchEnabled },
                            set: { _ in onToggleAutoSwitch() }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
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
