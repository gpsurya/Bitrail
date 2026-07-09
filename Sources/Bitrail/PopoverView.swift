import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var state: PlaybackState
    let onToggleAutoSwitch: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            qualityHeader
            nowPlayingCard
            transferCard
            deviceCard
            footer
        }
        .padding(12)
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Header

    private var qualityHeader: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Quality", symbol: "waveform")

                if let tier = state.qualityTier, let sr = state.sourceSampleRate, let bd = state.sourceBitDepth {
                    HStack(spacing: 10) {
                        Image(systemName: tier.symbolName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(tier.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                            Text(String(format: "%.1f kHz / %d bit", sr / 1000, bd))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else if state.transport == .bluetooth, let codec = state.bluetoothCodec, let rate = state.bluetoothCodecSampleRate {
                    HStack(spacing: 10) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(codec)
                                .font(.system(size: 15, weight: .semibold))
                            Text(String(format: "%.1f kHz (Bluetooth)", rate / 1000))
                                .font(.system(size: 12, design: .monospaced))
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
                                .font(.system(size: 15, weight: .semibold))
                            Text(String(format: bitDepthFormat(state.liveBitDepth), sr / 1000, state.liveBitDepth ?? 0))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    Text("No audio detected")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                if state.hasRateMismatch {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 10))
                        Text("Device is at \(formattedRate(state.liveSampleRate)), source is \(formattedRate(state.sourceSampleRate))")
                            .font(.system(size: 10))
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
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "Now Playing", symbol: "music.note")
                if let app = state.appName {
                    Text(app)
                        .font(.system(size: 13, weight: .medium))
                    if let title = state.trackTitle {
                        Text([title, state.trackArtist].compactMap { $0 }.joined(separator: " — "))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("Nothing playing")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Transfer

    // What's actually reaching the output device right now - the honest
    // answer to "what's actually transferred to my headphones," as opposed
    // to what the source app claims to be streaming (which no public API
    // exposes for Spotify/browsers - only Apple Music's own log lines).
    private var transferCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Transfer", symbol: "arrow.up.arrow.down")

                if state.transport == .bluetooth {
                    if let bitrate = state.transferBitrateKbps {
                        HStack(spacing: 10) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "~%.0f kbps", bitrate))
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Negotiated Bluetooth link cap")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    } else {
                        Text("Waiting for codec negotiation…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else if let bitrate = state.transferBitrateKbps {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.0f kbps", bitrate))
                                .font(.system(size: 15, weight: .semibold))
                            Text("Uncompressed PCM (exact, not estimated)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    Text("No output stream detected")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Text("Source app's own encoding bitrate (e.g. Spotify's) isn't exposed by any public API - this is what's actually leaving the Mac.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Device

    private var deviceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Output Device", symbol: "speaker.wave.2")

                HStack(spacing: 8) {
                    Image(systemName: state.transport.symbolName)
                        .foregroundStyle(.secondary)
                    Text(state.deviceName ?? "Unknown")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(state.transport.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }

                if state.transport == .wired {
                    Toggle("Auto-match sample rate", isOn: Binding(
                        get: { state.autoSwitchEnabled },
                        set: { _ in onToggleAutoSwitch() }
                    ))
                    .font(.system(size: 12))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                if state.transport == .bluetooth {
                    Text("Bluetooth codec/rate is fixed at connection time and can't be forced.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Footer

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var repoURL: URL {
        // Permalink to the release tag matching this build, so "what am I
        // running" always resolves to the exact matching release notes.
        URL(string: "https://github.com/gpsurya/Bitrail/releases/tag/v\(appVersion)")!
    }

    private var footer: some View {
        HStack {
            Link(destination: repoURL) {
                Text("Bitrail v\(appVersion)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            Spacer()
            Button("Quit", action: onQuit)
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }
}
